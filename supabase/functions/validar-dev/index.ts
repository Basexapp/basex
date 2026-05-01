import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import bcrypt from "https://esm.sh/bcryptjs@2.4.3";

serve(async (req: Request) => {
  try {
    const { email, senha } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 🔹 Busca apenas o hash no banco
    const { data, error } = await supabase
      .schema("tabelas_powertank")
      .from("desenvolvedor")
      .select("senha_facil")
      .eq("email", email)
      .maybeSingle();

    if (error) throw error;

    if (!data) {
      return new Response(
        JSON.stringify({ autorizado: false }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // 🔹 Compara senha digitada com hash salvo
    const senhaValida = await bcrypt.compare(senha, data.senha_facil);

    return new Response(
      JSON.stringify({ autorizado: senhaValida }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : "Erro desconhecido";
    return new Response(
      JSON.stringify({ erro: errorMessage }),
      { status: 400 }
    );
  }
});