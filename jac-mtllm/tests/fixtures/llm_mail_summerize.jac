
import from mtllm.llms {FakeLLM}
import from os {path}

glob llm = FakeLLM(
    responses_file=path.join(path.dirname(__file__), "llm_mail_summerize.json")
);


obj Email {
    has sender: str;
    has subject: str;
    has body: str;
}


"""
Generate 5 random emails.
"""
def generate_random_mails() -> list[Email] by llm();

"""
Gets an email instance and summerize the mail and return.
"""
def summerize_email(email: Email) -> str
    by llm();



with entry {
    emails = generate_random_mails();
    for email in emails {
        print(f"Sender: {email.sender}");
        print(f"Subject: {email.subject}");
        print(f"Body: {email.body}");
        print("Summary:", summerize_email(email));
        print('-' * 30);
    }
}

