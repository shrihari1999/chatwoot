/* global axios */
import ApiClient from '../ApiClient';

class TiktokShopChannel extends ApiClient {
  constructor() {
    super('tiktok/shop', { accountScoped: true });
  }

  generateAuthorization(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }
}

export default new TiktokShopChannel();
