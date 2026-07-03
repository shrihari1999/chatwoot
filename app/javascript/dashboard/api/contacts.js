/* global axios */
import ApiClient from './ApiClient';

export const buildContactParams = (page, sortAttr, label, search) => {
  let params = `include_contact_inboxes=false&page=${page}&sort=${sortAttr}`;
  if (search) {
    params = `${params}&q=${search}`;
  }
  if (label) {
    params = `${params}&labels[]=${label}`;
  }
  return params;
};

class ContactAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  get(page, sortAttr = 'name', label = '') {
    let requestURL = `${this.url}?${buildContactParams(
      page,
      sortAttr,
      label,
      ''
    )}`;
    return axios.get(requestURL);
  }

  show(id) {
    // include_contact_inboxes=true so the contact's source_id (Facebook/
    // Instagram PSID) is available on the contact profile.
    return axios.get(`${this.url}/${id}?include_contact_inboxes=true`);
  }

  update(id, data) {
    // Keep contact_inboxes (PSID) on the record after an edit round-trips.
    return axios.patch(`${this.url}/${id}?include_contact_inboxes=true`, data);
  }

  getConversations(contactId, { inboxId } = {}) {
    const params = inboxId ? { inbox_id: inboxId } : {};
    return axios.get(`${this.url}/${contactId}/conversations`, { params });
  }

  getAttachments(contactId, page = 1) {
    return axios.get(`${this.url}/${contactId}/attachments`, {
      params: { page },
    });
  }

  getContactableInboxes(contactId) {
    return axios.get(`${this.url}/${contactId}/contactable_inboxes`);
  }

  getContactLabels(contactId) {
    return axios.get(`${this.url}/${contactId}/labels`);
  }

  initiateCall(contactId, inboxId, conversationId = null) {
    return axios.post(`${this.url}/${contactId}/call`, {
      inbox_id: inboxId,
      conversation_id: conversationId,
    });
  }

  updateContactLabels(contactId, labels) {
    return axios.post(`${this.url}/${contactId}/labels`, { labels });
  }

  search(search = '', page = 1, sortAttr = 'name', label = '', options = {}) {
    let requestURL = `${this.url}/search?${buildContactParams(
      page,
      sortAttr,
      label,
      search
    )}`;
    return axios.get(requestURL, { signal: options.signal });
  }

  active(page = 1, sortAttr = 'name') {
    let requestURL = `${this.url}/active?${buildContactParams(page, sortAttr)}`;
    return axios.get(requestURL);
  }

  // eslint-disable-next-line default-param-last
  filter(page = 1, sortAttr = 'name', queryPayload) {
    let requestURL = `${this.url}/filter?${buildContactParams(page, sortAttr)}`;
    return axios.post(requestURL, queryPayload);
  }

  importContacts(file) {
    const formData = new FormData();
    formData.append('import_file', file);
    return axios.post(`${this.url}/import`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  destroyCustomAttributes(contactId, customAttributes) {
    return axios.post(`${this.url}/${contactId}/destroy_custom_attributes`, {
      custom_attributes: customAttributes,
    });
  }

  destroyAvatar(contactId) {
    return axios.delete(`${this.url}/${contactId}/avatar`);
  }

  exportContacts(queryPayload) {
    return axios.post(`${this.url}/export`, queryPayload);
  }
}

export default new ContactAPI();
