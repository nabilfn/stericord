import { useState, type FormEvent } from "react";
import { ShieldCheck } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { challengeAndVerifyMfaFactor, listMfaFactors, signOut } from "@/features/auth/api";

export function MfaChallengePage() {
  const { refreshMfaStatus } = useAuth();
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const factors = await listMfaFactors();
      const factor = factors.find((f) => f.status === "verified");
      if (!factor) throw new Error("No verified authenticator found for this account");
      await challengeAndVerifyMfaFactor(factor.id, code);
      await refreshMfaStatus();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Verification failed");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-navy px-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="text-center">
          <div className="mx-auto mb-3 flex h-10 w-10 items-center justify-center rounded-md bg-navy text-white">
            <ShieldCheck size={20} />
          </div>
          <CardTitle className="text-lg">Two-factor verification</CardTitle>
          <p className="text-sm text-slate-500">Enter the 6-digit code from your authenticator app.</p>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div>
              <Label htmlFor="mfa-code">Authentication code</Label>
              <Input
                id="mfa-code"
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                required
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              />
            </div>
            {error && <p className="text-sm text-fail">{error}</p>}
            <Button type="submit" className="w-full" disabled={submitting || code.length !== 6}>
              {submitting ? "Verifying…" : "Verify"}
            </Button>
            <button
              type="button"
              className="w-full text-center text-xs text-slate-400 hover:text-slate-600"
              onClick={() => void signOut()}
            >
              Sign in with a different account
            </button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
