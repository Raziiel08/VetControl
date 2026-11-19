import { createClient } from "@supabase/supabase-js";

const urlSupabase = import.meta.env.VITE_SUPABASE_URL;
const claveSupabase =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(urlSupabase, claveSupabase);
