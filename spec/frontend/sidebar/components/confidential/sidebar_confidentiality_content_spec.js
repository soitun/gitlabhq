import { GlIcon, GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SidebarConfidentialityContent from '~/sidebar/components/confidential/sidebar_confidentiality_content.vue';

describe('Sidebar Confidentiality Content', () => {
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findText = () => wrapper.find('[data-testid="confidential-text"]');
  const findCollapsedIcon = () => wrapper.find('[data-testid="sidebar-collapsed-icon"]');

  const createComponent = ({ confidential = false, issuableType = 'issue' } = {}) => {
    wrapper = shallowMount(SidebarConfidentialityContent, {
      propsData: {
        confidential,
        issuableType,
      },
    });
  };

  it('emits `expandSidebar` event on collapsed icon click', () => {
    createComponent();
    findCollapsedIcon().trigger('click');

    expect(wrapper.emitted('expandSidebar')).toHaveLength(1);
  });

  describe('when issue is non-confidential', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a non-confidential icon', () => {
      expect(findIcon().props('name')).toBe('eye');
    });

    it('does not add `is-active` class to the icon', () => {
      expect(findIcon().classes()).not.toContain('is-active');
    });

    it('displays a non-confidential text', () => {
      expect(findText().text()).toBe('Not confidential');
    });
  });

  describe('when issue is confidential', () => {
    it('renders a confidential icon', () => {
      createComponent({ confidential: true });
      expect(findIcon().props('name')).toBe('eye-slash');
    });

    it('adds `is-active` class to the icon', () => {
      createComponent({ confidential: true });
      expect(findIcon().classes()).toContain('is-active');
    });

    it('displays a correct confidential text for issue', () => {
      createComponent({ confidential: true });

      const alertEl = findText().findComponent(GlAlert);

      expect(alertEl.props()).toMatchObject({
        showIcon: false,
        dismissible: false,
        variant: 'warning',
      });
      expect(alertEl.text()).toBe(
        'Only project members with at least the Planner role, the author, and assignees can view or be notified about this issue.',
      );
    });

    it('displays a correct confidential text for epic', () => {
      createComponent({ confidential: true, issuableType: 'epic' });
      expect(findText().findComponent(GlAlert).text()).toBe(
        'Only group members with at least the Planner role can view or be notified about this epic.',
      );
    });
  });
});
