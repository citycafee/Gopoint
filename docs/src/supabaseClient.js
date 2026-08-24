import { createClient } from "@supabase/supabase-js"

const SUPABASE_URL = "https://jynjoiidearebmpsisom.supabase.co"
const SUPABASE_ANON_KEY = "sb_publishable_vwUSZCVzXy3FeNpKhayFAQ_LZ08abDX"

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
