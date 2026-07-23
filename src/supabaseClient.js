import { createClient } from "@supabase/supabase-js"

const SUPABASE_URL = "https://tsuhzwqrduluzbxmdoxq.supabase.co"
const SUPABASE_ANON_KEY = "sb_publishable_3kQN2CnO4h7ZxQbujz7eEQ_Q0jq0_Fj"

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
