import next from "eslint-config-next/core-web-vitals";

/** @type {import('eslint').Linter.Config[]} */
const eslintConfig = [
  {
    ignores: ["src-tauri/**", ".next/**", "out/**", "node_modules/**"],
  },
  ...next,
];

export default eslintConfig;
