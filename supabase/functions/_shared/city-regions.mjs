import catalog from './city-regions.v1.json' with { type: 'json' };

export const cityRegionCatalog = catalog;
export const normalizeRegionText = value => typeof value === 'string'
    ? value.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().trim().replace(/\s+/gu, ' ') : '';

export function resolveCityRegion({ city, countryCode, administrativeArea } = {}, data = catalog) {
    if (data.schemaVersion !== 1 || !normalizeRegionText(city) || !normalizeRegionText(countryCode)
        || !normalizeRegionText(administrativeArea)) return null;
    const matches = data.regions.filter(region => normalizeRegionText(region.countryCode) === normalizeRegionText(countryCode)
        && region.members.some(member => [member.administrativeArea, ...member.administrativeAliases]
            .some(name => normalizeRegionText(name) === normalizeRegionText(administrativeArea))
            && member.cities.some(name => normalizeRegionText(name) === normalizeRegionText(city))));
    return matches.length === 1 ? matches[0] : null;
}

export function presenceAdministrativeArea(body) {
    const value = body.administrativeArea;
    if (value == null) return null;
    if (typeof value !== 'string' || value.trim().length > 120) throw new TypeError('Invalid administrative area.');
    return value.trim() || null;
}
