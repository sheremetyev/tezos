import pytest
from tools.utils import assert_typecheck_data_failure
from client.client import Client


@pytest.mark.slow
@pytest.mark.contract
class TestAnnotations:
    """Tests of Michelson annotations."""
    def test_annotation_length_success(self, client: Client):
        client.typecheck_data('3', f"(int :{'a' * 254})")

    def test_annotation_length_failure(self, client: Client):
        assert_typecheck_data_failure(
            client, '3', f"(int :{'a' * 255})",
            r'annotation exceeded maximum length \(255 chars\)')
