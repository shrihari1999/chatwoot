import actionQueryGenerator from '../actionQueryGenerator';

const testData = [
  {
    action_name: 'add_label',
    action_params: [{ id: 'testlabel', name: 'testlabel' }],
  },
  {
    action_name: 'assign_team',
    action_params: [
      {
        id: 1,
        name: 'sales team',
        description: 'This is our internal sales team',
        allow_auto_assign: true,
        account_id: 1,
        is_member: true,
      },
    ],
  },
];

const finalResult = [
  {
    action_name: 'add_label',
    action_params: ['testlabel'],
  },
  {
    action_name: 'assign_team',
    action_params: [1],
  },
];

describe('#actionQueryGenerator', () => {
  it('returns the correct format of filter query', () => {
    expect(actionQueryGenerator(testData)).toEqual(finalResult);
    expect(
      actionQueryGenerator(testData).every(i => Array.isArray(i.action_params))
    ).toBe(true);
  });

  it('preserves change_custom_attribute hash payload across a re-save', () => {
    const loaded = [
      {
        action_name: 'change_custom_attribute',
        action_params: [{ attribute_key: 'sla_alerted', value: 'true' }],
      },
    ];
    expect(actionQueryGenerator(loaded)).toEqual([
      {
        action_name: 'change_custom_attribute',
        action_params: [{ attribute_key: 'sla_alerted', value: 'true' }],
      },
    ]);
  });

  it('wraps a fresh change_custom_attribute object into an array', () => {
    const fresh = [
      {
        action_name: 'change_custom_attribute',
        action_params: { attribute_key: 'sla_alerted', value: 'true' },
      },
    ];
    expect(actionQueryGenerator(fresh)).toEqual([
      {
        action_name: 'change_custom_attribute',
        action_params: [{ attribute_key: 'sla_alerted', value: 'true' }],
      },
    ]);
  });
});
