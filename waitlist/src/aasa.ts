/**
 * Universal Links contract for `/i/*` invite links only.
 *
 * `components` is scoped to `/i/*` deliberately — associating the whole domain
 * would pull `skygrid.my/privacy`, `/terms`, and `/support` into the app too,
 * and `AppRouter` doesn't handle those, so tapping them from Settings would go
 * silently nowhere. The App ID prefix (`NVZB82UK53`) is the Team ID from
 * `ios/project.yml`'s `DEVELOPMENT_TEAM`, which for this account matches the
 * App ID Prefix shown in the Apple Developer Portal.
 */
export const APPLE_APP_SITE_ASSOCIATION = {
  applinks: {
    apps: [] as string[],
    details: [
      {
        appIDs: ["NVZB82UK53.com.takmin.skygrid"],
        components: [{ "/": "/i/*" }]
      }
    ]
  }
};
