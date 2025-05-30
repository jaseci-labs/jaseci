"""Tests for Integration with Jaclang."""

import io
import sys

from jaclang import JacMachineInterface as Jac
from jaclang.utils.test import TestCase

# Import the jac_import function from JacMachineInterface
jac_import = Jac.py_jac_import


class JacLanguageTests(TestCase):
    """Tests for Integration with Jaclang."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()


    def test_llm_mail_summerize(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("llm_mail_summerize", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        summaries = [
            'AetherGuard reports a login to your account from a new device in Berlin and advises a password reset if the activity was unauthorized.',
            'Claire from Novelink invites writers to a biweekly Writer\'s Circle this Friday for sharing work and receiving feedback in a supportive environment.',
            'Marcus Bentley from FinTracker reports a weekly spending total of $342.65, mainly on Groceries, Transport, and Dining, with a link for detailed insights.',
            'TechNews from DailyByte highlights how quantum computing is set to transform fields like cryptography and climate modeling, with more details in the full article.',
            'Nora Hartwell from Wanderlust Travels offers a 30% discount on international trips booked this week, urging recipients to take advantage of the limited-time travel deal.',
        ]
        for summary in summaries:
            self.assertIn(summary, stdout_value)


    def test_with_llm_function(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_function", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn('(input) (str) = "Lets move to paris"', stdout_value)

    def test_with_llm_method(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_method", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("[Reasoning] <Reason>", stdout_value)
        self.assertIn(
            "(person) (Person) = Person(name=\"Albert Einstein\", age=76)",
            stdout_value,
        )

    def test_with_llm_lower(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_lower", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("[Reasoning] <Reason>", stdout_value)
        self.assertIn(
            '(name) (str) = "Oppenheimer"',
            stdout_value,
        )
        self.assertIn(
            '(Person) (object) eg:- Person(full_name=str, yod=int, personality=Personality)',
            stdout_value,
        )
        self.assertIn(
            "J. Robert Oppenheimer was a Introvert person who died in 1967",
            stdout_value,
        )


    # FIXME:
    #
    # def test_with_llm_type(self) -> None:
    #     """Parse micro jac file."""
    #     captured_output = io.StringIO()
    #     sys.stdout = captured_output
    #     jac_import("with_llm_type", base_path=self.fixture_abs_path("./"))
    #     sys.stdout = sys.__stdout__
    #     stdout_value = captured_output.getvalue()
    #     self.assertIn("14/03/1879", stdout_value)
    #     self.assertNotIn(
    #         'University (University) (obj) = type(__module__="with_llm_type", __doc__=None, '
    #         "_jac_entry_funcs_`=[`], _jac_exit_funcs_=[], __init__=function(__wrapped__=function()))",
    #         stdout_value,
    #     )
    #     desired_output_count = stdout_value.count(
    #         "Person(name='Jason Mars', dob='1994-01-01', age=30)"
    #     )
    #     self.assertEqual(desired_output_count, 2)

    def test_with_llm_image(self) -> None:
        """Test MTLLLM Image Implementation."""
        try:
            captured_output = io.StringIO()
            sys.stdout = captured_output
            jac_import("with_llm_image", base_path=self.fixture_abs_path("./"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            self.assertIn(
                "{'type': 'text', 'text': '\\n[System Prompt]\\n", stdout_value[:500]
            )
            self.assertNotIn(
                " {'type': 'text', 'text': 'Image of the Question (question_img) (Image) = '}, "
                "{'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQAB",
                stdout_value[:500],
            )
        except Exception:
            self.skipTest("This test requires Pillow to be installed.")

    def test_with_llm_video(self) -> None:
        """Test MTLLLM Video Implementation."""
        try:
            captured_output = io.StringIO()
            sys.stdout = captured_output
            jac_import("with_llm_video", base_path=self.fixture_abs_path("./"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            self.assertIn(
                "{'type': 'text', 'text': '\\n[System Prompt]\\n", stdout_value[:500]
            )
            self.assertEqual(stdout_value.count("data:image/jpeg;base64"), 4)
        except Exception:
            self.skipTest("This test requires OpenCV to be installed.")
