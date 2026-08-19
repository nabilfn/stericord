import { supabase } from "@/services/supabaseClient";

/**
 * Storage provider abstraction (master prompt section 22). Only the
 * operations Phase 2 actually uses are implemented here; archiveEvidence /
 * deleteExpiredEvidence belong to the retention lifecycle built in Phase 7
 * and will be added to this interface then, not stubbed out now.
 */
export interface StorageProvider {
  uploadEvidence(bucket: string, path: string, file: File): Promise<{ path: string }>;
  generateSignedUrl(bucket: string, path: string, expiresInSeconds: number): Promise<string>;
  calculateHash(file: File): Promise<string>;
}

class SupabaseStorageProvider implements StorageProvider {
  async uploadEvidence(bucket: string, path: string, file: File) {
    const { error } = await supabase.storage.from(bucket).upload(path, file, {
      contentType: file.type,
      upsert: false,
    });
    if (error) throw error;
    return { path };
  }

  async generateSignedUrl(bucket: string, path: string, expiresInSeconds: number) {
    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
    if (error) throw error;
    return data.signedUrl;
  }

  async calculateHash(file: File): Promise<string> {
    const buffer = await file.arrayBuffer();
    const digest = await crypto.subtle.digest("SHA-256", buffer);
    return Array.from(new Uint8Array(digest))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
  }
}

export const storageProvider: StorageProvider = new SupabaseStorageProvider();
