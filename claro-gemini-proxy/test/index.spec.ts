import {
	env,
	createExecutionContext,
	waitOnExecutionContext,
	SELF,
} from "cloudflare:test";
import { describe, it, expect } from "vitest";
import worker from "../src/index";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe("Gemini proxy worker contract", () => {
	it("rejects unsupported methods in the unit-style handler", async () => {
		const request = new IncomingRequest("http://example.com", {
			method: "GET",
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);

		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(405);
		expect(await response.text()).toBe("Method not allowed");
	});

	it("rejects requests without the app secret", async () => {
		const request = new IncomingRequest("http://example.com", {
			method: "POST",
		});
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);

		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Unauthorized");
	});

	it("returns the same method contract through the Worker runtime", async () => {
		const response = await SELF.fetch("https://example.com", {
			method: "GET",
		});

		expect(response.status).toBe(405);
		expect(await response.text()).toBe("Method not allowed");
	});

	it("returns the same authentication contract through the Worker runtime", async () => {
		const response = await SELF.fetch("https://example.com", {
			method: "POST",
		});

		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Unauthorized");
	});
});
