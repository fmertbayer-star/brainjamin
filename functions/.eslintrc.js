module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  ignorePatterns: [
    "lib/**/*",
    "/generated/**/*",
  ],
  rules: {
    // TS-only project — type system documents signatures; JSDoc rules from eslint-config-google are deprecated for TypeScript and add noise without value.
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
  },
  overrides: [
    {
      files: ["*.ts"],
      extends: [
        "eslint:recommended",
        "google",
        "plugin:@typescript-eslint/recommended",
      ],
      parser: "@typescript-eslint/parser",
      parserOptions: {
        project: ["./tsconfig.json"],
        sourceType: "module",
      },
      plugins: ["@typescript-eslint"],
      rules: {
        "require-jsdoc": "off",
        "valid-jsdoc": "off",
        "quotes": ["error", "double"],
        "import/no-unresolved": 0,
        "indent": ["error", 2],
        "max-len": ["error", {"code": 120}],
        "linebreak-style": "off",
      },
    },
  ],
};
