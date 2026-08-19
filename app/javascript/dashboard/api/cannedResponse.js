/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
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
