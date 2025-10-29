import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 🚀 Servidor da função Edge
serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // ⚠️ Service role: só no servidor
    );

    // 1️⃣ Extrai o token do utilizador que chamou a função
    const authHeader = req.headers.get("Authorization")!;
    if (!authHeader) {
      return new Response("Token não encontrado", { status: 401 });
    }

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // 2️⃣ Verifica quem chamou a função
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response("Não autenticado", { status: 401 });
    }

    // 3️⃣ Verifica se o utilizador logado é administrador
    const { data: perfil, error: perfilError } = await supabase
      .from("perfis")
      .select("cargo")
      .eq("id", user.id)
      .single();

    if (perfilError || perfil?.cargo?.toLowerCase() !== "administrador") {
      return new Response("Apenas administradores podem criar utilizadores", { status: 403 });
    }

    // 4️⃣ Lê o corpo do pedido
    const { email, password, nome_completo, cargo } = await req.json();

    if (!email || !password || !nome_completo || !cargo) {
      return new Response("Campos obrigatórios em falta", { status: 400 });
    }

    // 5️⃣ Cria o utilizador no Auth
    const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createError) {
      return new Response(createError.message, { status: 400 });
    }

    // 6️⃣ Cria o perfil correspondente
    await supabase.from("perfis").insert({
      id: newUser.user.id,
      nome_completo,
      cargo,
    });

    return new Response(
      JSON.stringify({ message: "Utilizador criado com sucesso", user_id: newUser.user.id }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error(error);
    return new Response("Erro interno no servidor", { status: 500 });
  }
});


/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/create_user' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
