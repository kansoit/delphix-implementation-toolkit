# Developer requests for `delphix-masking-helper`

These requests were identified while packaging the helper in the offline
`delphix-implementation-toolkit` OCI image.

## 1. Remove the Vite native config warning

The frontend build currently warns that the Vite configuration uses features that are unsupported
by `configLoader: 'native'` and may become unsupported when the native loader is enabled by default.

Requested changes:

- Replace `__dirname` with `import.meta.dirname` in `frontend/vite.config.ts`.
- Add the `.ts` extension to the local `vite-plugin-framework-guide` import.
- Keep the configuration compatible with the supported Vite versions.

The packaging project temporarily applied these changes locally so the image could be built without
the warning. They should be incorporated into the upstream helper repository.

## 2. Plan the migration from Tailwind CSS 3 to Tailwind CSS 4

The frontend dependency audit reports high-severity findings associated with the current Tailwind
CSS 3 dependency tree. A forced audit fix would migrate the project to Tailwind CSS 4 and may cause
breaking configuration or styling changes.

Requested changes:

- Evaluate and plan the Tailwind CSS 3 to 4 migration.
- Update the Vite/PostCSS/Tailwind configuration as required.
- Review the existing styles and verify the production build and GUI visually.
- Re-run dependency audits after the migration.

This should be handled as an explicit dependency migration, not as an unattended `npm audit fix
--force` operation.

## 3. Make version detection work for OCI/container deployments

The helper currently tries to read its version from a Git checkout. In a production OCI image the
runtime contains only the required application files, not `.git` metadata or the complete source
checkout. The UI therefore displays the `package.json` fallback and warns that it may be behind the
running code. It also suggests running `dlpx-helper update`, which is not the appropriate workflow
inside an offline, immutable container.

Requested changes:

- Support an explicit packaged version, for example through a build-time value or
  `DLPX_HELPER_VERSION`.
- Distinguish a packaged/container build from a source checkout in the version metadata.
- Do not recommend `dlpx-helper update` when the helper is running from an immutable OCI image.
- Expose the exact helper version and, when available, the source commit in `/api/version`.

The solution should work without requiring Git or `.git` metadata inside the runtime image.
