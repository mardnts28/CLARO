import {
	env,
	createExecutionContext,
	waitOnExecutionContext,
	SELF,
} from "cloudflare:test";
import { describe, it, expect } from "vitest";
import worker from "../src/index";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe("Health data worker contract", () => {
	it("rejects requests without an Authorization header", async () => {
		const request = new IncomingRequest("http://example.com/health-profile");
		const response = await worker.fetch(request, env);

		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Unauthorized");
	});

	it("rejects malformed bearer tokens", async () => {
		const request = new IncomingRequest("http://example.com/health-profile", {
			headers: { Authorization: "Bearer invalid-token" },
		});
		const response = await worker.fetch(request, env);

		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Invalid token");
	});

	it("returns the authentication contract through the Worker runtime", async () => {
		const response = await SELF.fetch("https://example.com/health-profile");

		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Unauthorized");
	});

	it("rejects malformed bearer tokens through the Worker runtime", async () => {
		const response = await SELF.fetch("https://example.com/health-profile", {
			headers: { Authorization: "Bearer invalid-token" },
		});

		expect(response.status).toBe(401);
		expect(await response.text()).toBe("Invalid token");
	});
});
