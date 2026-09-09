import { assertEquals } from "@std/assert";
import { sanitizeHostname } from "../commands/rebuild.ts";

Deno.test("sanitizeHostname keeps clean names unchanged", () => {
	assertEquals(sanitizeHostname("mini01"), "mini01");
	assertEquals(sanitizeHostname("mini03"), "mini03");
	assertEquals(sanitizeHostname("bring-the-heat-yo"), "bring-the-heat-yo");
});

Deno.test("sanitizeHostname lowercases and replaces separators", () => {
	assertEquals(sanitizeHostname("Mini 01"), "mini-01");
	assertEquals(sanitizeHostname("Bring the Heat Yo"), "bring-the-heat-yo");
});

Deno.test("sanitizeHostname strips Setup Assistant punctuation", () => {
	assertEquals(sanitizeHostname("mini01’s Mac mini"), "mini01-s-mac-mini");
	assertEquals(
		sanitizeHostname("ifiokjr's MacBook Pro"),
		"ifiokjr-s-macbook-pro",
	);
});

Deno.test("sanitizeHostname trims and collapses hyphens", () => {
	assertEquals(sanitizeHostname("--mini--01--"), "mini-01");
	assertEquals(sanitizeHostname("  192  "), "192");
	assertEquals(sanitizeHostname("''"), "");
});
