import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { basename, extname } from "node:path";

const textExtensions = new Set([
    ".entitlements", ".json", ".md", ".mjs", ".pbxproj", ".plist",
    ".sql", ".swift", ".toml", ".ts", ".xcstrings", ".xcscheme", ".xml", ".yml", ".yaml",
]);
const extensionlessTextFiles = new Set([".env.example", ".gitignore"]);
const forbidden = [
    { name: "Supabase secret key", pattern: /sb_secret_[A-Za-z0-9_-]{12,}/u },
    { name: "private key material", pattern: /-----BEGIN (?:EC |RSA )?PRIVATE KEY-----/u },
    { name: "credentialed Postgres URL", pattern: /postgres(?:ql)?:\/\/[^\s:/]+:[^\s@]+@/u },
];

test("tracked source files contain no deploy-time secrets", () => {
    const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z"])
        .toString("utf8")
        .split("\0")
        .filter(Boolean)
        .filter(file => textExtensions.has(extname(file))
            || extensionlessTextFiles.has(basename(file))
            || file.endsWith(".env.example"));
    const leaks = [];
    for (const file of files) {
        const contents = readFileSync(file, "utf8");
        for (const rule of forbidden) {
            if (rule.pattern.test(contents)) leaks.push(`${file}: ${rule.name}`);
        }
    }
    assert.deepEqual(leaks, []);
});
