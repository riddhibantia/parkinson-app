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

const schema = z
  .object({
    email: z.string().email("Enter a valid email"),
    password: z.string().min(8, "Minimum 8 characters"),
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, { message: "Passwords do not match", path: ["confirm"] });

type Form = z.infer<typeof schema>;

export default function SignupPage() {
  const router = useRouter();
  const setUserId = useAppStore((s) => s.setUserId);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const { register, handleSubmit, formState } = useForm<Form>({ resolver: zodResolver(schema) });

  const onSubmit = async (v: Form) => {
    setError("");
    setNotice("");
    const supa = supabaseBrowser();
    if (!supa) {
      setError("Backend not configured — connect Supabase to sign up.");
      return;
    }
    const { data, error } = await supa.auth.signUp({ email: v.email, password: v.password });
    if (error) {
      setError(error.message);
      return;
    }
    if (!data.session) {
      setNotice("Account created — check your email to confirm, then log in.");
      return;
    }
    setUserId(data.user?.id ?? null);
    router.replace("/consent");
  };

  return (
    <div className="mx-auto max-w-md">
      <h1 className="text-2xl font-bold">Sign up</h1>
      {!isSupabaseConfigured && (
        <p className="mt-2 text-sm text-amber-700">Backend not configured — sign-up is disabled.</p>
      )}
      <Card className="mt-4">
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <Field label="Email" error={formState.errors.email?.message}>
            <input className={inputCls} type="email" autoComplete="email" {...register("email")} />
          </Field>
          <Field label="Password" error={formState.errors.password?.message}>
            <input className={inputCls} type="password" autoComplete="new-password" {...register("password")} />
          </Field>
          <Field label="Confirm password" error={formState.errors.confirm?.message}>
            <input className={inputCls} type="password" autoComplete="new-password" {...register("confirm")} />
          </Field>
          {error && <p className="text-sm text-red-600">{error}</p>}
          {notice && <p className="text-sm text-teal-700">{notice}</p>}
          <PrimaryButton type="submit">Create account</PrimaryButton>
        </form>
      </Card>
    </div>
  );
}
