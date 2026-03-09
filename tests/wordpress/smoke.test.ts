/**
 * WordPress Smoke Tests
 *
 * Verify the DDEV WordPress instance is running and accessible.
 * These are intentionally simple — they confirm the test infrastructure
 * works and DDEV is reachable before running any Construkted-specific tests.
 */

import { describe, it, expect, beforeAll } from "vitest";
import { WpClient, createWpClient } from "./helpers/wp-client";

describe("WordPress Smoke Tests", () => {
  let wp: WpClient;

  beforeAll(() => {
    wp = createWpClient();
  });

  it("homepage returns 200", async () => {
    const res = await wp.get("/");
    expect(res.status).toBe(200);
  });

  it("wp-login.php returns 200", async () => {
    const res = await wp.get("/wp-login.php");
    expect(res.status).toBe(200);
  });

  it("wp-json returns REST API index", async () => {
    const res = await wp.rest<{ namespaces?: string[] }>("");
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("namespaces");
    expect(Array.isArray(res.body.namespaces)).toBe(true);
  });

  it("admin-ajax.php returns 400 without action (expected behavior)", async () => {
    // WordPress returns 400 Bad Request when no valid AJAX action is provided
    const res = await wp.post("/wp-admin/admin-ajax.php");
    expect(res.status).toBe(400);
  });
});
