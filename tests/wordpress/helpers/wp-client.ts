/**
 * WordPress HTTP Client Helper
 *
 * Black-box HTTP client for making requests to a running WordPress instance.
 * Used by functional tests to verify AJAX handlers and REST API endpoints.
 *
 * Uses native fetch (Node 18+). No external HTTP client dependencies.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface WpClientConfig {
  /** Base URL of the WordPress site (no trailing slash). */
  baseUrl: string;
  /** Default request timeout in milliseconds. */
  timeout: number;
  /** Optional cookies string for authenticated requests (e.g. from wp-login.php). */
  cookies?: string;
  /** Optional WordPress application password (Base64 "user:password"). */
  applicationPassword?: string;
}

export interface WpResponse<T = unknown> {
  status: number;
  headers: Headers;
  body: T;
  ok: boolean;
}

export interface AjaxParams {
  action: string;
  [key: string]: string | number | boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildConfig(overrides?: Partial<WpClientConfig>): WpClientConfig {
  return {
    baseUrl: (
      overrides?.baseUrl ??
      process.env.WP_TEST_URL ??
      "https://construkted-develop-01.ddev.site"
    ).replace(/\/+$/, ""),
    timeout: overrides?.timeout ?? 10_000,
    cookies: overrides?.cookies,
    applicationPassword:
      overrides?.applicationPassword ?? process.env.WP_APP_PASSWORD,
  };
}

function buildHeaders(config: WpClientConfig): Record<string, string> {
  const headers: Record<string, string> = {};

  if (config.cookies) {
    headers["Cookie"] = config.cookies;
  }

  if (config.applicationPassword) {
    headers["Authorization"] = `Basic ${config.applicationPassword}`;
  }

  return headers;
}

/**
 * Parse response body as JSON if content-type indicates JSON,
 * otherwise return the raw text.
 *
 * WordPress with WP_DEBUG_DISPLAY enabled may prepend PHP notices/warnings
 * as HTML before the JSON payload. When that happens, we attempt to extract
 * the JSON portion from the raw text.
 */
async function parseBody(response: Response): Promise<unknown> {
  const ct = response.headers.get("content-type") ?? "";

  if (ct.includes("application/json")) {
    const text = await response.text();
    try {
      return JSON.parse(text);
    } catch {
      // WordPress may prepend PHP notices (HTML) before the JSON body.
      // Try to find the first '{' or '[' and parse from there.
      const jsonStart = Math.min(
        ...[text.indexOf("{"), text.indexOf("[")].filter((i) => i !== -1),
      );
      if (Number.isFinite(jsonStart) && jsonStart > 0) {
        try {
          return JSON.parse(text.slice(jsonStart));
        } catch {
          // Fall through — return raw text so callers can inspect it.
        }
      }
      return text;
    }
  }

  return response.text();
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

export class WpClient {
  readonly config: WpClientConfig;

  constructor(overrides?: Partial<WpClientConfig>) {
    this.config = buildConfig(overrides);
  }

  // ---- Core request methods ------------------------------------------------

  async get<T = unknown>(
    path: string,
    options?: { headers?: Record<string, string> },
  ): Promise<WpResponse<T>> {
    const url = `${this.config.baseUrl}${path}`;

    const response = await fetch(url, {
      method: "GET",
      headers: {
        ...buildHeaders(this.config),
        ...options?.headers,
      },
      signal: AbortSignal.timeout(this.config.timeout),
      // @ts-expect-error -- Node-specific option for self-signed DDEV certs
      dispatcher: undefined,
    });

    const body = (await parseBody(response)) as T;

    return {
      status: response.status,
      headers: response.headers,
      body,
      ok: response.ok,
    };
  }

  async post<T = unknown>(
    path: string,
    data?: Record<string, string | number | boolean> | FormData | string,
    options?: {
      headers?: Record<string, string>;
      contentType?: string;
    },
  ): Promise<WpResponse<T>> {
    const url = `${this.config.baseUrl}${path}`;

    let body: string | FormData | undefined;
    const headers: Record<string, string> = {
      ...buildHeaders(this.config),
      ...options?.headers,
    };

    if (data instanceof FormData) {
      body = data;
    } else if (typeof data === "string") {
      body = data;
      if (!headers["Content-Type"] && !options?.contentType) {
        headers["Content-Type"] = "application/x-www-form-urlencoded";
      }
    } else if (data !== undefined) {
      // Encode plain object as URL-encoded form data (what admin-ajax.php expects)
      body = new URLSearchParams(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ).toString();
      headers["Content-Type"] = "application/x-www-form-urlencoded";
    }

    if (options?.contentType) {
      headers["Content-Type"] = options.contentType;
    }

    const response = await fetch(url, {
      method: "POST",
      headers,
      body,
      signal: AbortSignal.timeout(this.config.timeout),
    });

    const parsed = (await parseBody(response)) as T;

    return {
      status: response.status,
      headers: response.headers,
      body: parsed,
      ok: response.ok,
    };
  }

  // ---- WordPress-specific helpers ------------------------------------------

  /**
   * Call admin-ajax.php with the given action and optional extra params.
   *
   * WordPress responds with 400 when no valid action handler is found, and
   * with 0 (literally the string "0") for failed auth checks. Successful
   * handlers typically return JSON via wp_send_json_success / wp_send_json_error.
   */
  async ajax<T = unknown>(params: AjaxParams): Promise<WpResponse<T>> {
    return this.post<T>("/wp-admin/admin-ajax.php", params as Record<string, string>);
  }

  /**
   * Call a WP REST API endpoint.
   *
   * @param endpoint  Path relative to /wp-json/ (e.g. "ck/v1/projects")
   */
  async rest<T = unknown>(
    endpoint: string,
    options?: {
      method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
      body?: Record<string, unknown>;
      headers?: Record<string, string>;
    },
  ): Promise<WpResponse<T>> {
    const cleanEndpoint = endpoint.replace(/^\/+/, "");
    const path = `/wp-json/${cleanEndpoint}`;

    if (!options?.method || options.method === "GET") {
      return this.get<T>(path, { headers: options?.headers });
    }

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...options?.headers,
    };

    const url = `${this.config.baseUrl}${path}`;

    const response = await fetch(url, {
      method: options.method,
      headers: {
        ...buildHeaders(this.config),
        ...headers,
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      signal: AbortSignal.timeout(this.config.timeout),
    });

    const parsed = (await parseBody(response)) as T;

    return {
      status: response.status,
      headers: response.headers,
      body: parsed,
      ok: response.ok,
    };
  }
}

/**
 * Create a pre-configured WpClient instance.
 * Reads WP_TEST_URL and WP_APP_PASSWORD from environment if set.
 */
export function createWpClient(
  overrides?: Partial<WpClientConfig>,
): WpClient {
  return new WpClient(overrides);
}
