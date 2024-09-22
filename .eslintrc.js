module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
  },
  extends: [
    "standard",
    "plugin:node/recommended",
  ],
  parserOptions: {
    ecmaVersion: 12,
  },
  rules: {
    "quotes": [2, "single"],
    "camelcase": 0,
    "no-console": 0,
    "no-multi-spaces": 0,
    "no-debugger": 1,
    "operator-linebreak": [2, "after", { "overrides": { "?": "before", ":": "before" } }],
    "semi": [2, "never"],
    "no-unused-vars": ["error", { "args": "none" }],
    "no-trailing-spaces": 2,
    "no-useless-escape": 0,
    "no-empty-function": "warn",
    "space-infix-ops": "off",
    "padded-blocks": ["off"],
    "comma-dangle": ["error", "only-multiline"],
    "spaced-comment": 0,
    "no-multiple-empty-lines": 0,
    "no-unused-vars": 0,
    "array-bracket-spacing": 0,
    "space-before-function-paren": 0,
  },
  globals: { network: true },
  overrides: [
    {
      files: ["hardhat.config.js"],
      globals: { task: true, network: true },
    }
  ]
}
