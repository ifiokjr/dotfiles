import { assertEquals } from "@std/assert";
import {
	loginShellFromDscl,
	loginShellFromGetent,
} from "../commands/doctor.ts";

Deno.test("loginShellFromDscl parses macOS UserShell output", () => {
	assertEquals(
		loginShellFromDscl("UserShell: /run/current-system/sw/bin/nu\n"),
		"/run/current-system/sw/bin/nu",
	);
	assertEquals(
		loginShellFromDscl("UserShell: /bin/zsh\n"),
		"/bin/zsh",
	);
	assertEquals(loginShellFromDscl(""), "");
});

Deno.test("loginShellFromGetent parses the passwd shell field", () => {
	assertEquals(
		loginShellFromGetent("minione:x:501:20::/Users/minione:/bin/bash"),
		"/bin/bash",
	);
	assertEquals(
		loginShellFromGetent(
			"minione:x:501:20::/Users/minione:/run/current-system/sw/bin/nu\n",
		),
		"/run/current-system/sw/bin/nu",
	);
	assertEquals(loginShellFromGetent(""), "");
});
