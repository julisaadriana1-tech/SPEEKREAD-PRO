// Genera el audio nativo (Azure Neural TTS) de las lecciones publicadas que aún
// no tienen audio, lo sube a Supabase Storage y guarda la URL.
// Se corre desde tu computadora, NO desde la app:
//
//   cd scripts
//   npm install
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=eastus node generate-audio.mjs
//
// En Windows (PowerShell) definí las variables antes con:  $env:SUPABASE_URL="..."

import { createClient } from "@supabase/supabase-js";

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  AZURE_SPEECH_KEY,
  AZURE_SPEECH_REGION,
  VOICE = "en-US-AvaMultilingualNeural",
} = process.env;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !AZURE_SPEECH_KEY || !AZURE_SPEECH_REGION) {
  console.error("Faltan variables de entorno. Mirá el comentario al inicio del archivo.");
  process.exit(1);
}

const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function escapeXml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}

async function synthesize(text) {
  const ssml = `<speak version="1.0" xml:lang="en-US"><voice name="${VOICE}">` +
    `<prosody rate="-5%">${escapeXml(text)}</prosody></voice></speak>`;
  const res = await fetch(`https://${AZURE_SPEECH_REGION}.tts.speech.microsoft.com/cognitiveservices/v1`, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": AZURE_SPEECH_KEY,
      "Content-Type": "application/ssml+xml",
      "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
      "User-Agent": "speakread-audio-script",
    },
    body: ssml,
  });
  if (!res.ok) throw new Error(`Azure TTS ${res.status}: ${await res.text()}`);
  return Buffer.from(await res.arrayBuffer());
}

async function upload(path, bytes) {
  const { error } = await db.storage.from("lesson-audio")
    .upload(path, bytes, { contentType: "audio/mpeg", upsert: true });
  if (error) throw error;
  return db.storage.from("lesson-audio").getPublicUrl(path).data.publicUrl;
}

const { data: lessons, error } = await db.from("lessons")
  .select("id, title, body_en, audio_url, lesson_sentences(id, idx, text_en, audio_url)")
  .eq("published", true);
if (error) throw error;

for (const lesson of lessons) {
  if (!lesson.audio_url) {
    const url = await upload(`${lesson.id}/full.mp3`, await synthesize(lesson.body_en));
    await db.from("lessons").update({ audio_url: url }).eq("id", lesson.id);
    console.log("✓ texto completo:", lesson.title);
  }
  for (const s of lesson.lesson_sentences) {
    if (s.audio_url) continue;
    const url = await upload(`${lesson.id}/s${s.idx}.mp3`, await synthesize(s.text_en));
    await db.from("lesson_sentences").update({ audio_url: url }).eq("id", s.id);
  }
  console.log("✓ oraciones:", lesson.title);
}
console.log("Listo.");
