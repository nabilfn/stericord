import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ShieldCheck, ShieldOff, Trash2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { useAuth } from "@/contexts/AuthContext";
import {
  challengeAndVerifyMfaFactor,
  enrollMfaFactor,
  listMfaFactors,
  unenrollMfaFactor,
} from "@/features/auth/api";

type TotpFactor = Awaited<ReturnType<typeof listMfaFactors>>[number];

export function MfaSettings() {
  const queryClient = useQueryClient();
  const { refreshMfaStatus } = useAuth();
  const [enrollment, setEnrollment] = useState<{ factorId: string; qrCode: string; secret: string } | null>(null);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);

  const factorsQuery = useQuery({ queryKey: ["mfa-factors"], queryFn: listMfaFactors });

  const enrollMutation = useMutation({
    mutationFn: enrollMfaFactor,
    onSuccess: (data) => {
      setError(null);
      setEnrollment({ factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret });
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Could not start enrollment"),
  });

  const verifyMutation = useMutation({
    mutationFn: () => challengeAndVerifyMfaFactor(enrollment!.factorId, code),
    onSuccess: async () => {
      setEnrollment(null);
      setCode("");
      setError(null);
      await queryClient.invalidateQueries({ queryKey: ["mfa-factors"] });
      await refreshMfaStatus();
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Invalid code"),
  });

  const unenrollMutation = useMutation({
    mutationFn: unenrollMfaFactor,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["mfa-factors"] });
      await refreshMfaStatus();
    },
  });

  useEffect(() => {
    if (!enrollment) setCode("");
  }, [enrollment]);

  const factors: TotpFactor[] = factorsQuery.data ?? [];
  const verifiedFactor = factors.find((f) => f.status === "verified");

  return (
    <Card>
      <CardHeader className="flex flex-row items-center gap-2">
        {verifiedFactor ? <ShieldCheck size={16} className="text-pass" /> : <ShieldOff size={16} className="text-slate-400" />}
        <div>
          <CardTitle>Two-factor authentication</CardTitle>
          <p className="text-xs text-slate-500">
            Require an authenticator app code at sign-in, in addition to your password.
          </p>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {verifiedFactor && !enrollment && (
          <div className="flex items-center justify-between rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
            <div>
              <p className="text-sm font-medium text-slate-800">Authenticator app enabled</p>
              <p className="text-xs text-slate-500">Enrolled {new Date(verifiedFactor.created_at).toLocaleDateString()}</p>
            </div>
            <Button
              variant="danger"
              onClick={() => unenrollMutation.mutate(verifiedFactor.id)}
              disabled={unenrollMutation.isPending}
            >
              <Trash2 size={14} />
              Disable
            </Button>
          </div>
        )}

        {!verifiedFactor && !enrollment && (
          <Button onClick={() => enrollMutation.mutate()} disabled={enrollMutation.isPending}>
            {enrollMutation.isPending ? "Starting…" : "Enable two-factor authentication"}
          </Button>
        )}

        {enrollment && (
          <div className="space-y-3 rounded-md border border-slate-200 p-4">
            <p className="text-sm text-slate-600">
              Scan this QR code with an authenticator app (Google Authenticator, 1Password, Authy), then enter the
              6-digit code it shows.
            </p>
            {/* QR code SVG returned directly by Supabase Auth, not user input */}
            <div
              className="mx-auto h-40 w-40"
              dangerouslySetInnerHTML={{ __html: enrollment.qrCode }}
            />
            <p className="text-center text-xs text-slate-400">
              Can't scan? Enter this key manually: <span className="font-mono">{enrollment.secret}</span>
            </p>
            <div>
              <Label htmlFor="verify-code">Verification code</Label>
              <Input
                id="verify-code"
                inputMode="numeric"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              />
            </div>
            <div className="flex gap-2">
              <Button
                onClick={() => verifyMutation.mutate()}
                disabled={code.length !== 6 || verifyMutation.isPending}
              >
                {verifyMutation.isPending ? "Verifying…" : "Verify and enable"}
              </Button>
              <Button variant="secondary" onClick={() => setEnrollment(null)}>
                Cancel
              </Button>
            </div>
          </div>
        )}

        {error && <p className="text-sm text-fail">{error}</p>}
      </CardContent>
    </Card>
  );
}
