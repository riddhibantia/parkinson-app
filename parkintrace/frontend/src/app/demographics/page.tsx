"use client";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { Card, Field, PrimaryButton, inputCls } from "@/components/ui";
import { supabaseBrowser } from "@/lib/supabaseClient";

/** Context only. Typing experience never gates measurement and never
 *  becomes an ML feature (spec 5.2). All fields optional. */
const schema = z.object({
  age: z.string().optional(),
  gender: z.enum(["male", "female", "prefer_not_to_say", "unknown", ""]).optional(),
  typingExperience: z.enum(["regular", "occasional", "not_familiar", ""]).optional(),
  parkinsonContext: z.enum(["diagnosed", "monitoring", "research", ""]).optional(),
  diagnosisYear: z.string().optional(),
});

type Form = z.infer<typeof schema>;

export default function DemographicsPage() {
  const router = useRouter();
  const { register, handleSubmit } = useForm<Form>({ resolver: zodResolver(schema) });

  const onSubmit = async (v: Form) => {
    const supa = supabaseBrowser();
    if (supa) {
      const { data } = await supa.auth.getUser();
      if (data.user) {
        await supa.from("profiles").upsert({
          id: data.user.id,
          age: v.age ? Number(v.age) : null,
          gender: v.gender || null,
          typing_experience: v.typingExperience || null,
          parkinson_context: {
            context: v.parkinsonContext || null,
            diagnosis_year: v.diagnosisYear ? Number(v.diagnosisYear) : null,
          },
        });
      }
    }
    try {
      localStorage.setItem("parkintrace-context", JSON.stringify(v));
    } catch {
      /* private mode */
    }
    router.push("/layer");
  };

  return (
    <div className="mx-auto max-w-xl">
      <h1 className="text-2xl font-bold">Context</h1>
      <p className="mt-1 text-sm text-slate-600">
        Optional background. Nothing here blocks or delays your first measured session.
      </p>
      <Card className="mt-4">
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <Field label="Age (optional)">
            <input className={inputCls} type="number" min={0} max={130} {...register("age")} />
          </Field>
          <Field label="Sex / gender (optional)">
            <select className={inputCls} {...register("gender")} defaultValue="">
              <option value="">Prefer not to say</option>
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="prefer_not_to_say">Prefer not to say</option>
              <option value="unknown">Unknown</option>
            </select>
          </Field>
          <Field label="Typing experience (context only — no practice session)">
            <select className={inputCls} {...register("typingExperience")} defaultValue="">
              <option value="">Skip</option>
              <option value="regular">Regular / experienced</option>
              <option value="occasional">Occasional</option>
              <option value="not_familiar">Not familiar</option>
            </select>
          </Field>
          <Field label="Parkinson context (optional)">
            <select className={inputCls} {...register("parkinsonContext")} defaultValue="">
              <option value="">Skip</option>
              <option value="diagnosed">Diagnosed</option>
              <option value="monitoring">Monitoring possible changes</option>
              <option value="research">Healthy / research participant</option>
            </select>
          </Field>
          <Field label="Diagnosis year (optional, diagnosed participants)">
            <input className={inputCls} type="number" min={1900} max={2100} {...register("diagnosisYear")} />
          </Field>
          <PrimaryButton type="submit">Continue</PrimaryButton>
        </form>
      </Card>
    </div>
  );
}
