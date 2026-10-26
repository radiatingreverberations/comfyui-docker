"""Regression checks for the native-kernel layer's content-based cache key."""

import importlib.util
from pathlib import Path
import unittest


HELPER = Path(__file__).resolve().parents[1] / "src" / "extract_kernel_requirements.py"
SPEC = importlib.util.spec_from_file_location("extract_kernel_requirements", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
extract = MODULE.extract_kernel_requirements


class KernelRequirementsTests(unittest.TestCase):
    def test_docs_update_keeps_kernel_input_identical(self):
        before = (
            "comfyui-embedded-docs==0.5.13\n"
            "comfy-kitchen==0.2.37\n"
            "comfy-aimdo==0.5.6\n"
            "cryptography\n"
        )
        after = before.replace("0.5.13", "0.5.14").replace("cryptography\n", "")
        self.assertEqual(extract(before), extract(after))
        self.assertEqual(
            extract(after), "comfy-aimdo==0.5.6\ncomfy-kitchen==0.2.37\n"
        )

    def test_kernel_upgrade_changes_cache_input(self):
        self.assertNotEqual(
            extract("comfy-kitchen==0.2.37\n"),
            extract("comfy-kitchen==0.2.40\n"),
        )

    def test_normalizes_names_and_preserves_extras_and_markers(self):
        requirement = 'Comfy_Kitchen[cublas]>=0.2.37; python_version >= "3.12"'
        self.assertEqual(extract("  " + requirement + " # native kernels\n"), requirement + "\n")

    def test_ignores_comments_and_similarly_named_packages(self):
        self.assertEqual(
            extract("# comfy-kitchen==0.2.37\ncomfy-kitchen-tools==1.0\ncomfyui-embedded-docs==0.5.14\n"),
            "",
        )

    def test_reordering_other_requirements_does_not_change_kernel_input(self):
        self.assertEqual(
            extract("torch\ncomfy-kitchen==0.2.37\ncomfy-aimdo==0.5.6\n"),
            extract("comfy-aimdo==0.5.6\ncomfy-kitchen==0.2.37\nnumpy\n"),
        )


if __name__ == "__main__":
    unittest.main()
