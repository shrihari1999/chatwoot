/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class CannedResponse extends CacheEnabledApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'canned_response';
  }

  // The index endpoint returns a bare array instead of a payload wrapper
  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: dataToParse };
  }

  get({ searchKey, categoryId, filterByVisibility } = {}) {
    const params = new URLSearchParams();
    if (searchKey) params.append('search', searchKey);
    if (categoryId) params.append('category_id', categoryId);
    // Restricts the result to categories the current user is allowed to see.
    // Used by the conversation canned-response picker, not the settings page.
    if (filterByVisibility) params.append('visible', 'true');
    const query = params.toString();
    const url = query ? `${this.url}?${query}` : this.url;
    return axios.get(url);
  }

  // Records that a wording was just used, so the next insertion gets the following
  // one. Fired without awaiting -- the text is already in the composer.
  advanceVariant(id) {
    return axios.post(`${this.url}/${id}/advance_variant`);
  }
}

export default new CannedResponse();
