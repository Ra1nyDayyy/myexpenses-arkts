import { describe, it, expect } from '@ohos/hypium';
import { InlineExpansionState } from '../main/ets/ui/InlineExpansionState';

export default function inlineExpansionStateTest() {
  describe('InlineExpansionState', () => {
    it('toggles_boolean_expansion_without_persisting_ui_state', 0, () => {
      expect(InlineExpansionState.toggle(false)).assertEqual(true);
      expect(InlineExpansionState.toggle(true)).assertEqual(false);
    });

    it('opens_one_exclusive_row_and_closes_it_when_selected_again', 0, () => {
      expect(InlineExpansionState.toggleExclusive(-1, 12)).assertEqual(12);
      expect(InlineExpansionState.toggleExclusive(12, 12)).assertEqual(-1);
    });

    it('switches_exclusive_expansion_directly_to_another_row', 0, () => {
      expect(InlineExpansionState.toggleExclusive(12, 27)).assertEqual(27);
    });
  });
}
