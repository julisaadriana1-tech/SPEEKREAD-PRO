// Edge Function: assess-pronunciation
// Recibe el audio grabado (WAV 16 kHz mono, en base64) y el texto de referencia,
// lo evalúa con Azure Speech Pronunciation Assessment y devuelve el puntaje
// global y por palabra / fonema. Las claves de Azure solo viven aquí.
//
// Secretos necesarios (supabase secrets set ...):
//   AZURE_SPEECH_KEY     clave del recurso Speech de Azure
//   AZURE_SPEECH_REGION  región del recurso, ej. "eastus"
// SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY los provee Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_AUDIO_BYTES = 2_000_000; // ~60 s de WAV 16 kHz mono
const MAX_TEXT_CHARS = 1200;

type AzureScores = {
  AccuracyScore?: number;
  FluencyScore?: number;
  CompletenessScore?: number;
  PronScore?: number;
  ProsodyScore?: number;
  ErrorType?: string;
};
type AzurePhoneme = { Phoneme: string; PronunciationAssessment?: AzureScores } & AzureScores;
type AzureWord = {
  Word: string;
  PronunciationAssessment?: AzureScores;
  Phonemes?: AzurePhoneme[];
} & AzureScores;
type AzureNBest = {
  Display?: string;
  PronunciationAssessment?: AzureScores;
  Words?: AzureWord[];
} & AzureScores;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function round(n: number | undefined | null): number | null {
  return typeof n === "number" ? Math.round(n) : null;
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function utf8ToBase64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const azureKey = Deno.env.get("AZURE_SPEECH_KEY");
    const azureRegion = Deno.env.get("AZURE_SPEECH_REGION");
    if (!azureKey || !azureRegion) return json({ error: "azure_not_configured" }, 500);

    // 1. Verificar quién llama
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);
    const user = userData.user;

    // 2. Validar la entrada
    const body = await req.json();
    const referenceText: unknown = body?.referenceText;
    const audioBase64: unknown = body?.audioBase64;
    const lessonId: string | null = body?.lessonId ?? null;
    const sentenceId: string | null = body?.sentenceId ?? null;
    const language: string = body?.language === "en-GB" ? "en-GB" : "en-US";

    if (typeof referenceText !== "string" || referenceText.trim().length === 0 ||
        referenceText.length > MAX_TEXT_CHARS) {
      return json({ error: "invalid_reference_text" }, 400);
    }
    if (typeof audioBase64 !== "string" || audioBase64.length === 0) {
      return json({ error: "missing_audio" }, 400);
    }
    const audio = base64ToBytes(audioBase64);
    if (audio.byteLength > MAX_AUDIO_BYTES) return json({ error: "audio_too_long" }, 413);

    // 3. Llamar a Azure Pronunciation Assessment (REST, audio corto)
    const params = {
      ReferenceText: referenceText,
      GradingSystem: "HundredMark",
      Granularity: "Phoneme",
      Dimension: "Comprehensive",
      EnableMiscue: true,
      EnableProsodyAssessment: true,
      PhonemeAlphabet: "IPA",
    };
    const azureUrl =
      `https://${azureRegion}.stt.speech.microsoft.com/speech/recognition/conversation/` +
      `cognitiveservices/v1?language=${language}&format=detailed`;

    const azureRes = await fetch(azureUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": azureKey,
        "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
        "Pronunciation-Assessment": utf8ToBase64(JSON.stringify(params)),
        Accept: "application/json",
      },
      body: audio,
    });

    if (!azureRes.ok) {
      const detail = await azureRes.text();
      console.error("Azure error", azureRes.status, detail);
      return json({ error: "azure_error", status: azureRes.status }, 502);
    }

    const az = await azureRes.json();
    const best: AzureNBest | undefined = az?.NBest?.[0];
    if (az?.RecognitionStatus !== "Success" || !best) {
      return json({
        status: "no_speech",
        message: "No pudimos escucharte bien. Probá de nuevo, más cerca del micrófono.",
      });
    }

    // Azure puede devolver los puntajes directos o dentro de PronunciationAssessment
    const pa: AzureScores = best.PronunciationAssessment ?? best;
    const words = (best.Words ?? []).map((w) => {
      const wpa: AzureScores = w.PronunciationAssessment ?? w;
      return {
        word: w.Word,
        score: round(wpa.AccuracyScore) ?? 0,
        errorType: wpa.ErrorType ?? "None",
        phonemes: (w.Phonemes ?? []).map((p) => ({
          phoneme: p.Phoneme,
          score: round((p.PronunciationAssessment ?? p).AccuracyScore) ?? 0,
        })),
      };
    });

    const result = {
      status: "ok",
      overall: round(pa.PronScore ?? pa.AccuracyScore) ?? 0,
      accuracy: round(pa.AccuracyScore),
      fluency: round(pa.FluencyScore),
      completeness: round(pa.CompletenessScore),
      prosody: round(pa.ProsodyScore),
      recognizedText: best.Display ?? "",
      words,
    };

    // 4. Guardar el intento (con service role: el usuario no puede escribir puntajes)
    const admin = createClient(supabaseUrl, serviceKey);
    const { error: insertError } = await admin.from("pronunciation_attempts").insert({
      user_id: user.id,
      lesson_id: lessonId,
      sentence_id: sentenceId,
      reference_text: referenceText,
      overall_score: result.overall,
      accuracy: result.accuracy,
      fluency: result.fluency,
      completeness: result.completeness,
      prosody: result.prosody,
      words,
    });
    if (insertError) console.error("insert error", insertError.message);

    return json(result);
  } catch (e) {
    console.error(e);
    return json({ error: "internal_error" }, 500);
  }
});
