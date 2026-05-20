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
}

export default new CannedResponse();
