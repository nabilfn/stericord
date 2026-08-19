import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider } from "@/contexts/AuthContext";
import { ProtectedRoute } from "@/routes/ProtectedRoute";
import { AppShell } from "@/components/layout/AppShell";
import { LoginPage } from "@/features/auth/LoginPage";
import { DashboardPage } from "@/features/dashboard/DashboardPage";
import { EquipmentListPage } from "@/features/equipment/EquipmentListPage";
import { EquipmentDetailPage } from "@/features/equipment/EquipmentDetailPage";
import { CyclesListPage } from "@/features/cycles/CyclesListPage";
import { CycleDetailPage } from "@/features/cycles/CycleDetailPage";
import { PackDetailPage } from "@/features/packs/PackDetailPage";
import { PointOfUsePage } from "@/features/ot/PointOfUsePage";
import { IncidentsListPage } from "@/features/incidents/IncidentsListPage";
import { IncidentDetailPage } from "@/features/incidents/IncidentDetailPage";
import { QuarantineListPage } from "@/features/quarantine/QuarantineListPage";
import { UsersPage } from "@/features/users/UsersPage";
import { SettingsPage } from "@/features/settings/SettingsPage";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route
              element={
                <ProtectedRoute>
                  <AppShell />
                </ProtectedRoute>
              }
            >
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/equipment" element={<EquipmentListPage />} />
              <Route path="/equipment/:id" element={<EquipmentDetailPage />} />
              <Route path="/cycles" element={<CyclesListPage />} />
              <Route path="/cycles/:id" element={<CycleDetailPage />} />
              <Route path="/packs/:id" element={<PackDetailPage />} />
              <Route path="/point-of-use" element={<PointOfUsePage />} />
              <Route path="/incidents" element={<IncidentsListPage />} />
              <Route path="/incidents/:id" element={<IncidentDetailPage />} />
              <Route path="/quarantine" element={<QuarantineListPage />} />
              <Route path="/users" element={<UsersPage />} />
              <Route path="/settings" element={<SettingsPage />} />
            </Route>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
