"use client";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { Card, Field, PrimaryButton, inputCls } from "@/components/ui";
import { supabaseBrowser } from "@/lib/supabaseClient";
import { isSupabaseConfigured } from "@/lib/config";
import { useAppStore } from "@/store/useAppStore";

const schema = z.object({
  email: z.string().email("Enter a valid email"),
  password: z.string().min(8, "Minimum 8 characters"),
});

type Form = z.infer<typeof schema>;

export default function LoginPage() {
  const router = useRouter();
  const setUserId = useAppStore((s) => s.setUserId);
  const onboardingCompleted = useAppStore((s) => s.onboardingCompleted);
  const [error, setError] = useState("");
  const { register, handleSubmit, formState } = useForm<Form>({ resolver: zodResolver(schema) });

  const onSubmit = async (v: Form) => {
    setError("");
    const supa = supabaseBrowser();
    if (!supa) {
      setError("Backend not configured — connect Supabase to sign in.");
      return;
    }
    const { data, error } = await supa.auth.signInWithPassword(v);
    if (error) {
      setError(error.message);
      return;
    }
    setUserId(data.user?.id ?? null);
    router.replace(onboardingCompleted ? "/dashboard" : "/consent");
  };

  return (
    <div className="mx-auto max-w-md">
      <h1 className="text-2xl font-bold">Log in</h1>
      {!isSupabaseConfigured && (
        <p className="mt-2 text-sm text-amber-700">Backend not configured — sign-in is disabled.</p>
      )}
      <Card className="mt-4">
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <Field label="Email" error={formState.errors.email?.message}>
            <input className={inputCls} type="email" autoComplete="email" {...register("email")} />
          </Field>
          <Field label="Password" error={formState.errors.password?.message}>
            <input className={inputCls} type="password" autoComplete="current-password" {...register("password")} />
          </Field>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <PrimaryButton type="submit">Log in</PrimaryButton>
        </form>
      </Card>
      <p className="mt-3 text-sm text-slate-600">
        No account? <a className="font-semibold text-teal-700" href="/signup">Sign up</a>
      </p>
    </div>
  );
}
