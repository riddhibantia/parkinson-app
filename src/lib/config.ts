export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
// No hardcoded localhost in production: the dev-only fallback applies
// solely to non-production builds; production without an explicit
// NEXT_PUBLIC_API_URL runs honestly degraded (analysis disabled).
const RAW_API = process.env.NEXT_PUBLIC_API_URL ?? "";
const DEV_FALLBACK = process.env.NODE_ENV !== "production" ? "http://localhost:8000" : "";
export const API_URL = (RAW_API || DEV_FALLBACK).replace(/\/$/, "");

export const isSupabaseConfigured = SUPABASE_URL.length > 0 && SUPABASE_ANON_KEY.length > 0;
export const isApiConfigured = API_URL.length > 0;

export const DISCLAIMER =
  "ParkinTrace is a research screening and monitoring aid. It is not a medical device and its output is not a diagnosis.";
