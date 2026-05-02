import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
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
    const { email, senha } = await req.json();

    const hoje = new Date().toISOString().slice(0, 10);

    const client = new Client(Deno.env.get("SUPABASE_DB_URL")!);
    await client.connect();

    // 🔒 Busca tentativas globais do dia
    const tentativa = await client.queryObject<{ tentativas: number }>(
      `SELECT tentativas 
       FROM tabelas_powertank.tentativas_dev_global
       WHERE data = $1
       LIMIT 1`,
      [hoje]
    );

    const tentativasHoje = tentativa.rows[0]?.tentativas ?? 0;

    // 🚫 Bloqueio global
    if (tentativasHoje >= 3) {
      await client.end();
      await delay(800);
      return new Response(
        JSON.stringify({ autorizado: false, erro: "limite atingido no dia" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 🔐 Validação com hash (crypt)
    const result = await client.queryObject<{ id: string }>(
      `SELECT id 
       FROM tabelas_powertank.desenvolvedor
       WHERE email = $1
         AND senha_facil = crypt($2, senha_facil)
       LIMIT 1`,
      [email.trim().toLowerCase(), senha.trim()]
    );

    const sucesso = result.rows.length > 0;

    // 🔁 Incrementa tentativas (sempre que tentar, acertando ou não)
    if (tentativa.rows.length > 0) {
      await client.queryObject(
        `UPDATE tabelas_powertank.tentativas_dev_global
         SET tentativas = tentativas + 1
         WHERE data = $1`,
        [hoje]
      );
    } else {
      await client.queryObject(
        `INSERT INTO tabelas_powertank.tentativas_dev_global (data, tentativas)
         VALUES ($1, 1)`,
        [hoje]
      );
    }

    await client.end();

    await delay(800);

    return new Response(
      JSON.stringify({ autorizado: sucesso }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    await delay(800);
    return new Response(
      JSON.stringify({ erro: err instanceof Error ? err.message : "erro" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});