import localUnitTest from './LocalUnit.test';
import aiExecutorSafetyTest from './AiExecutorSafety.test';
import aiIntentCoreTest from './AiIntentCore.test';
import insightCalculatorTest from './InsightCalculator.test';
import inlineExpansionStateTest from './InlineExpansionState.test';

export default function testsuite() {
  localUnitTest();
  aiExecutorSafetyTest();
  aiIntentCoreTest();
  insightCalculatorTest();
  inlineExpansionStateTest();
}
