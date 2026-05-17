// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Payload = {
  login_id?: string;
  login_id_column_missing?: boolean;
  password?: string;
  profile?: Record<string, any>;
};

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

    const callerClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );

    const {
      data: { user: caller },
      error: callerErr,
    } = await callerClient.auth.getUser();
    if (callerErr || !caller) {
      return jsonResponse(401, { error: "Invalid caller session" });
    }

    const { data: callerProfile, error: profileErr } = await adminClient
      .from("profiles")
      .select("id, is_admin")
      .eq("id", caller.id)
      .maybeSingle();

    if (profileErr) {
      return jsonResponse(500, {
        error: "Failed to validate admin profile",
        details: profileErr.message,
      });
    }

    if (!callerProfile || callerProfile.is_admin !== true) {
      return jsonResponse(403, { error: "Only admins can create users" });
    }

    const payload = (await req.json()) as Payload;
    const loginId = (payload.login_id ?? "").trim();
    const password = payload.password ?? "";
    const profile = payload.profile ?? {};
    const loginIdColumnMissing = payload.login_id_column_missing === true;

    if (!loginId || !password || !profile.full_name) {
      return jsonResponse(400, {
        error: "login_id, password, and profile.full_name are required",
      });
    }

    const email = loginId.includes("@")
      ? loginId
      : `${loginId}@runanubandh.local`;

    const {
      data: createdUser,
      error: createUserError,
    } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createUserError || !createdUser.user) {
      return jsonResponse(400, {
        error: "Failed to create auth user",
        details: createUserError?.message ?? "Unknown error",
      });
    }

    const userId = createdUser.user.id;
    const nowIso = new Date().toISOString();
    const profileRow: Record<string, unknown> = {
      id: userId,
      email,
      full_name: profile.full_name ?? "",
      gender: profile.gender ?? "Male",
      phone_number: profile.phone_number ?? null,
      date_of_birth: profile.date_of_birth || null,
      education: profile.education ?? null,
      occupation: profile.occupation ?? null,
      city: profile.city ?? null,
      height: profile.height ?? null,
      profile_photo_url: profile.profile_photo_url ?? null,
      biodata_url: profile.biodata_url ?? null,
      is_paid: profile.is_paid ?? true,
      payment_exempt: profile.payment_exempt ?? true,
      created_by_admin: profile.created_by_admin ?? true,
      prompt_password_change: profile.prompt_password_change ?? true,
      created_by: caller.id,
      updated_at: nowIso,
    };

    if (!loginIdColumnMissing) {
      profileRow.login_id = loginId;
    }

    const { error: upsertErr } = await adminClient
      .from("profiles")
      .upsert(profileRow, { onConflict: "id" });

    if (upsertErr) {
      await adminClient.auth.admin.deleteUser(userId);
      return jsonResponse(400, {
        error: "Failed to create profile row",
        details: upsertErr.message,
      });
    }

    return jsonResponse(200, {
      success: true,
      user_id: userId,
      email,
      login_id: loginId,
      login_id_saved: !loginIdColumnMissing,
    });
  } catch (e) {
    return jsonResponse(500, {
      error: "Unexpected error",
      details: e instanceof Error ? e.message : String(e),
    });
  }
});
