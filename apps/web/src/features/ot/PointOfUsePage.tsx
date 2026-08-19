import { useState, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Search, ScanLine } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Badge } from "@/components/ui/Badge";
import { findPackByCode } from "@/features/packs/api";
import { checkPackEligibility, recordPointOfUseVerification, type EligibilityResult } from "@/features/ot/api";
import { PackStatusBadge } from "@/features/packs/PackStatusBadge";
import { EvidenceUploadForm } from "@/features/evidence/EvidenceUploadForm";
import { EvidenceList } from "@/features/evidence/EvidenceList";
import type { InstrumentPack, VerificationResult } from "@/types/database";

export function PointOfUsePage() {
  const queryClient = useQueryClient();
  const [code, setCode] = useState("");
  const [pack, setPack] = useState<InstrumentPack | null>(null);
  const [eligibility, setEligibility] = useState<EligibilityResult | null>(null);
  const [patientReference, setPatientReference] = useState("");
  const [encounterReference, setEncounterReference] = useState("");
  const [notes, setNotes] = useState("");
  const [result, setResult] = useState<VerificationResult | "">("");
  const [searchError, setSearchError] = useState<string | null>(null);
  const [outcome, setOutcome] = useState<{ result: VerificationResult } | null>(null);

  const searchMutation = useMutation({
    mutationFn: async (searchCode: string) => {
      const found = await findPackByCode(searchCode.trim());
      if (!found) throw new Error("No pack found with that code");
      const eligibilityResult = await checkPackEligibility(found.id);
      return { found, eligibilityResult };
    },
    onSuccess: ({ found, eligibilityResult }) => {
      setPack(found);
      setEligibility(eligibilityResult);
      setOutcome(null);
      setSearchError(null);
    },
    onError: (err) => {
      setPack(null);
      setEligibility(null);
      setSearchError(err instanceof Error ? err.message : "Pack lookup failed");
    },
  });

  const verifyMutation = useMutation({
    mutationFn: () =>
      recordPointOfUseVerification({
        packId: pack!.id,
        result: result as VerificationResult,
        patientReference: patientReference || undefined,
        encounterReference: encounterReference || undefined,
        notes: notes || undefined,
      }),
    onSuccess: (record) => {
      setOutcome({ result: record.verification_result });
      void queryClient.invalidateQueries({ queryKey: ["notifications"] });
      void queryClient.invalidateQueries({ queryKey: ["incidents"] });
      void queryClient.invalidateQueries({ queryKey: ["quarantines"] });
    },
  });

  function handleSearch(e: FormEvent) {
    e.preventDefault();
    if (!code.trim()) return;
    searchMutation.mutate(code);
  }

  function reset() {
    setCode("");
    setPack(null);
    setEligibility(null);
    setPatientReference("");
    setEncounterReference("");
    setNotes("");
    setResult("");
    setOutcome(null);
    setSearchError(null);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Point of Use Verification</h1>
        <p className="text-sm text-slate-500">Scan or enter a pack code before use at OT / ward.</p>
      </div>

      <Card>
        <CardContent>
          <form className="flex items-end gap-2" onSubmit={handleSearch}>
            <div className="flex-1">
              <Label htmlFor="pack_code_search">Pack code or QR</Label>
              <Input
                id="pack_code_search"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="PACK-2026-0891"
              />
            </div>
            <Button type="submit" disabled={searchMutation.isPending}>
              <Search size={16} />
              {searchMutation.isPending ? "Looking up…" : "Look up"}
            </Button>
          </form>
          {searchError && <p className="mt-2 text-sm text-fail">{searchError}</p>}
        </CardContent>
      </Card>

      {pack && eligibility && !outcome && (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>{pack.pack_code}</CardTitle>
            <PackStatusBadge status={pack.status} />
          </CardHeader>
          <CardContent className="space-y-4">
            {!eligibility.eligible ? (
              <div className="rounded-md bg-red-50 p-4 text-sm text-fail">
                <p className="font-semibold">Not eligible for use</p>
                <p>{eligibility.reason}</p>
              </div>
            ) : (
              <>
                <Badge tone="pass">Eligible for use</Badge>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <Label htmlFor="patient_ref">Patient reference (optional)</Label>
                    <Input
                      id="patient_ref"
                      value={patientReference}
                      onChange={(e) => setPatientReference(e.target.value)}
                      placeholder="External MRN / reference"
                    />
                  </div>
                  <div>
                    <Label htmlFor="encounter_ref">Encounter reference (optional)</Label>
                    <Input
                      id="encounter_ref"
                      value={encounterReference}
                      onChange={(e) => setEncounterReference(e.target.value)}
                      placeholder="External encounter ID"
                    />
                  </div>
                </div>

                <div>
                  <Label>Indicator evidence</Label>
                  <EvidenceUploadForm entityType="instrument_pack" entityId={pack.id} />
                  <div className="mt-2">
                    <EvidenceList entityType="instrument_pack" entityId={pack.id} />
                  </div>
                </div>

                <div>
                  <Label>Verification result</Label>
                  <div className="flex gap-2">
                    {(["PASS", "FAIL", "UNDETERMINED"] as VerificationResult[]).map((r) => (
                      <button
                        key={r}
                        type="button"
                        onClick={() => setResult(r)}
                        className={`flex-1 rounded-md border px-3 py-2 text-sm font-medium ${
                          result === r
                            ? r === "PASS"
                              ? "border-pass bg-emerald-50 text-pass"
                              : r === "FAIL"
                                ? "border-fail bg-red-50 text-fail"
                                : "border-warning bg-amber-50 text-warning"
                            : "border-slate-200 text-slate-600 hover:bg-slate-50"
                        }`}
                      >
                        {r}
                      </button>
                    ))}
                  </div>
                </div>

                <div>
                  <Label htmlFor="pou_notes">Notes</Label>
                  <textarea
                    id="pou_notes"
                    rows={2}
                    className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-navy focus:outline-none focus:ring-1 focus:ring-navy"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                  />
                </div>

                {verifyMutation.isError && (
                  <p className="text-sm text-fail">
                    {verifyMutation.error instanceof Error ? verifyMutation.error.message : "Failed to record"}
                  </p>
                )}

                <Button
                  className="w-full"
                  disabled={!result || verifyMutation.isPending}
                  onClick={() => verifyMutation.mutate()}
                >
                  {verifyMutation.isPending ? "Recording…" : "Record Verification"}
                </Button>
              </>
            )}
          </CardContent>
        </Card>
      )}

      {outcome && (
        <Card>
          <CardContent className="space-y-3 py-8 text-center">
            <ScanLine size={32} className="mx-auto text-slate-400" />
            {outcome.result === "PASS" && (
              <p className="text-lg font-semibold text-pass">PASS — pack marked as used.</p>
            )}
            {outcome.result === "FAIL" && (
              <p className="text-lg font-semibold text-fail">
                FAIL — pack quarantined, incident created, CSSD alerted.
              </p>
            )}
            {outcome.result === "UNDETERMINED" && (
              <p className="text-lg font-semibold text-warning">UNDETERMINED — requires further manual review.</p>
            )}
            <Button variant="secondary" onClick={reset}>
              Scan next pack
            </Button>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
