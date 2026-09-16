// APNs transport environment and app identity are independent. TestFlight uses
// production APNs even when the app itself is the staging app.
const apps = Object.freeze({
  'com.yangwy30.whereismyfriend': 'whereismyfriend',
  'com.yangwy30.whereismyfriend.staging': 'whereismyfriend-staging',
});
export function pushRoute(body, env = () => undefined) {
  const environment = body.environment;
  if (!['sandbox', 'production'].includes(environment)) throw new TypeError('Invalid APNs environment.');
  const suffix = environment === 'sandbox' ? 'SANDBOX' : 'PRODUCTION';
  const bundleID = body.bundleID ?? env(`APNS_${suffix}_BUNDLE_ID`);
  if (typeof bundleID !== 'string' || !Object.hasOwn(apps, bundleID)) throw new TypeError('Unsupported notification app.');
  return {bundleID, urlScheme: apps[bundleID]};
}
