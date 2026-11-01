// Edge Function: generate-lesson (solo administradores)
// Genera una lección completa con OpenAI a partir de un brief y la guarda como
// BORRADOR (published = false). Una persona la revisa y la publica.
//
// Secretos necesarios:
//   OPENAI_API_KEY
//   OPENAI_MODEL   (opcional, por defecto "gpt-4.1-mini")
//
// Ejemplo de body:
// { "cefr_level": "B1", "context": "work", "topic": "risk",
//   "brief": "How to escalate a blocker to the sponsor", "unit": 2, "order_index": 3 }

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const LEVEL_GUIDE: Record<string, string> = {
  A1: "60-80 words, present simple, very common words, short sentences (max 10 words).",
  A2: "100-150 words, present and past simple, common workplace words, sentences up to 14 words.",
  B1: "180-250 words, mix of tenses, modal verbs, connectors (because, so, however).",
  B2: "250-350 words, complex sentences, professional collocations, some idioms.",
  C1: "350-500 words, executive register, nuanced vocabulary, hedging language.",
  C2: "500-700 words, native-level business writing, rhetorical structure.",
};

const lessonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "body_en", "body_es", "sentences", "vocabulary", "quiz"],
  properties: {
    title: { type: "string" },
    body_en: { type: "string" },
    body_es: { type: "string" },
    sentences: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["text_en", "text_es"],
        properties: { text_en: { type: "string" }, text_es: { type: "string" } },
      },
    },
    vocabulary: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["word", "ipa", "definition_en", "translation_es", "example_en"],
        properties: {
          word: { type: "string" },
          ipa: { type: "string" },
          definition_en: { type: "string" },
          translation_es: { type: "string" },
          example_en: { type: "string" },
        },
      },
    },
    quiz: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["type", "prompt", "options", "answer", "explanation"],
        properties: {
          type: { type: "string", enum: ["mc", "tf", "gap", "context"] },
          prompt: { type: "string" },
          options: { type: "array", items: { type: "string" } },
          answer: { type: "string" },
          explanation: { type: "string" },
        },
      },
    },
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const openaiKey = Deno.env.get("OPENAI_API_KEY");
    const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4.1-mini";
    if (!openaiKey) return json({ error: "openai_not_configured" }, 500);

    // Solo administradores
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: userData } = await userClient.auth.getUser();
    if (!userData?.user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: profile } = await admin
      .from("profiles").select("is_admin").eq("id", userData.user.id).single();
    if (!profile?.is_admin) return json({ error: "forbidden" }, 403);

    const { cefr_level, context, topic, brief, unit = 1, order_index = 1 } = await req.json();
    if (!LEVEL_GUIDE[cefr_level] || !["work", "life"].includes(context) || !topic || !brief) {
      return json({ error: "invalid_brief" }, 400);
    }

    const system = [
      "You write English reading lessons for Spanish-speaking adult professionals (~30 years old).",
      "Audience: project managers, analysts and team leads who use tools like Jira, Azure DevOps and Power BI.",
      "The text must feel like real content: an email, a meeting, a status report, or a realistic adult situation.",
      "NEVER use childish or school examples (no pets, toys, classrooms, 'Tommy has a ball').",
      `CEFR level ${cefr_level}: ${LEVEL_GUIDE[cefr_level]}`,
      "Return: body_en; body_es (natural Latin American Spanish translation);",
      "5-8 sentences taken VERBATIM from body_en for read-aloud practice;",
      "5-8 vocabulary items that appear in body_en, with IPA (American English);",
      "6-8 quiz questions mixing types: mc (4 options), tf (options exactly [\"True\",\"False\"]),",
      "gap (prompt with ______ and 4 options), context (inference question, 4 options).",
      "The answer must be exactly one of the options. Explanations quote the text.",
    ].join("\n");

    const user = `Context: ${context === "work" ? "workplace" : "adult daily life"}. Topic: ${topic}. Brief: ${brief}`;

    const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${openaiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: system }, { role: "user", content: user }],
        response_format: {
          type: "json_schema",
          json_schema: { name: "lesson", strict: true, schema: lessonSchema },
        },
      }),
    });
    if (!aiRes.ok) {
      console.error("OpenAI error", aiRes.status, await aiRes.text());
      return json({ error: "openai_error" }, 502);
    }
    const ai = await aiRes.json();
    const lesson = JSON.parse(ai.choices[0].message.content);

    // Validación mínima: la respuesta debe estar entre las opciones
    lesson.quiz = lesson.quiz.filter((q: { options: string[]; answer: string }) =>
      q.options.includes(q.answer)
    );

    const words = lesson.body_en.split(/\s+/).length;
    const { data: inserted, error } = await admin.from("lessons").insert({
      cefr_level, context, topic, unit, order_index,
      title: lesson.title,
      body_en: lesson.body_en,
      body_es: lesson.body_es,
      est_minutes: Math.max(5, Math.round(words / 25)),
      published: false,
    }).select("id").single();
    if (error) throw error;

    const lessonId = inserted.id;
    await admin.from("lesson_sentences").insert(
      lesson.sentences.map((s: { text_en: string; text_es: string }, i: number) => ({
        lesson_id: lessonId, idx: i + 1, text_en: s.text_en, text_es: s.text_es,
      })),
    );
    await admin.from("vocabulary").insert(
      lesson.vocabulary.map((v: Record<string, string>) => ({ lesson_id: lessonId, ...v })),
    );
    await admin.from("quiz_questions").insert(
      lesson.quiz.map((q: Record<string, unknown>, i: number) => ({
        lesson_id: lessonId, idx: i + 1, ...q,
      })),
    );

    return json({ lesson_id: lessonId, title: lesson.title, published: false });
  } catch (e) {
    console.error(e);
    return json({ error: "internal_error" }, 500);
  }
});
