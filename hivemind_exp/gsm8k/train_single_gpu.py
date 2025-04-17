import logging

import colorlog
from trl import GRPOConfig, ModelConfig, TrlParser

from hivemind_exp.chain_utils import (
    ModalSwarmCoordinator,
    WalletSwarmCoordinator,
    setup_web3,
)
from hivemind_exp.gsm8k.generate_prompts import get_stage1_samples
from hivemind_exp.runner.gensyn.testnet_grpo_runner import (
    TestnetGRPOArguments,
    TestnetGRPORunner,
)
from hivemind_exp.runner.grpo_runner import GRPOArguments, GRPORunner

import signal
import sys


def handle_termination(signum, frame):
    logging.info(f"Received signal {signum}. Cleaning up...")
    # Insert any cleanup logic here (e.g., save model state, disconnect swarm, etc.)
    sys.exit(0)


signal.signal(signal.SIGINT, handle_termination)
signal.signal(signal.SIGTERM, handle_termination)


def main():
    # Setup logging.
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)

    # Console handler with color formatting
    console_handler = colorlog.StreamHandler()
    console_handler.setFormatter(
        colorlog.ColoredFormatter("%(green)s%(levelname)s:%(name)s:%(message)s")
    )
    root_logger.addHandler(console_handler)

    # File handler
    file_handler = logging.FileHandler('training.log')
    file_handler.setFormatter(
        logging.Formatter('%(asctime)s:%(levelname)s:%(name)s:%(message)s')
    )
    root_logger.addHandler(file_handler)

    parser = TrlParser((ModelConfig, GRPOArguments, TestnetGRPOArguments, GRPOConfig))  # type: ignore
    model_args, grpo_args, testnet_args, training_args = parser.parse_args_and_config()

    # Run main training loop.
    if org_id := testnet_args.modal_org_id:
        runner = TestnetGRPORunner(ModalSwarmCoordinator(org_id, web3=setup_web3()))
    elif priv_key := testnet_args.wallet_private_key:
        runner = TestnetGRPORunner(WalletSwarmCoordinator(priv_key, web3=setup_web3()))
    else:
        runner = GRPORunner()

    runner.run(model_args, grpo_args, training_args, get_stage1_samples)


if __name__ == "__main__":
    main()
