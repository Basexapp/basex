import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const body = await req.json();
    const linhas = body?.linhas || [];

    const results = [];
    
    for (const linha of linhas) {
      if (linha && linha[0] && linha[0].toString().trim()) {
        const { data, error } = await supabase
          .from("google")
          .upsert({
            placa: linha[0].toString().trim().toUpperCase(),
            anp: linha[1]?.toString().trim() || null,
            cliente: linha[2]?.toString().trim() || null
          }, {
            onConflict: "placa"
          })
          .select();
        
        results.push({
          placa: linha[0],
          success: !error,
          error: error?.message || null
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        total: results.length,
        inserted: results.filter(r => r.success).length,
        results: results
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});