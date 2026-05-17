import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse(405, { error: "Method not allowed" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(500, {
        error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY",
      });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(401, { error: "Missing Authorization header" });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user },
      error: userErr,
    } = await callerClient.auth.getUser();

    if (userErr || !user) {
      return jsonResponse(401, { error: "Invalid caller session" });
    }

    const userId = user.id;

    // Best-effort related data cleanup.
    await adminClient.from("saved_profiles").delete().eq("user_id", userId);
    await adminClient
      .from("saved_profiles")
      .delete()
      .eq("saved_profile_id", userId);
    await adminClient.from("interests").delete().eq("sender_id", userId);
    await adminClient.from("interests").delete().eq("receiver_id", userId);
    await adminClient.from("messages").delete().eq("sender_id", userId);
    await adminClient.from("messages").delete().eq("receiver_id", userId);

    // Optional table; ignore missing table / permission issues.
    try {
      await adminClient.from("user_blocks").delete().eq("blocker_id", userId);
      await adminClient.from("user_blocks").delete().eq("blocked_id", userId);
    } catch (_) {
      // no-op
    }

    await adminClient.from("profiles").delete().eq("id", userId);
    const { error: authDeleteErr } = await adminClient.auth.admin.deleteUser(
      userId,
    );
    if (authDeleteErr) {
      return jsonResponse(400, {
        error: "Failed to delete auth user",
        details: authDeleteErr.message,
      });
    }

    return jsonResponse(200, { success: true, deleted_user_id: userId });
  } catch (e) {
    return jsonResponse(500, {
      error: "Unexpected error",
      details: e instanceof Error ? e.message : String(e),
    });
  }
});
