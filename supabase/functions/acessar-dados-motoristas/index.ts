import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const delay = (ms: number) =>
  new Promise((resolve) => setTimeout(resolve, ms));

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 🔐 1. Verificar token
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(
        JSON.stringify({ erro: "não autenticado" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 🔐 2. Validar usuário
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ erro: "token inválido" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 📥 3. Dados da requisição
    const { pessoa_id } = await req.json();

    if (!pessoa_id) {
      return new Response(
        JSON.stringify({ erro: "pessoa_id obrigatório" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 🛢️ 4. Conexão com banco (acesso total)
    const client = new Client(Deno.env.get("SUPABASE_DB_URL")!);
    await client.connect();

    // 🔍 5. Consulta segura (1 registro apenas)
    const result = await client.queryObject<{
      cpf: string;
      cnh: string;
    }>(
      `
      SELECT cpf, cnh
      FROM tabelas_powertank.dados_motoristas
      WHERE pessoa_id = $1
      LIMIT 1
      `,
      [pessoa_id]
    );

    await client.end();

    // ⏳ 6. Delay anti brute force
    await delay(500);

    if (result.rows.length === 0) {
      return new Response(
        JSON.stringify({ autorizado: false }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ✅ 7. Retorno
    return new Response(
      JSON.stringify({
        autorizado: true,
        cpf: result.rows[0].cpf,
        cnh: result.rows[0].cnh,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );

  } catch (err) {
    await delay(500);
    return new Response(
      JSON.stringify({ erro: err instanceof Error ? err.message : "erro" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});