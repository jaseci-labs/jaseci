node Person{
    has name: str;
}

edge Role{}

node Doctor{
    has specialty: str;
    has receivables: int = 0;
}

node Patient{
    has balance: int = 0;
}

edge is_treating{}
edge treated_by{}

node Claim{
    has cost: int;
}

node InsuranceProvider{
    has deductible: int;
}

walker ClaimProcessing{
    has claim: Claim;
    has fraction: float = 0.8; #Example: we pay 80% of the claim cost
    has we_pay: int by postinit;

    def postinit{
        self.we_pay = int(self.claim.cost * self.fraction);
    }

    can update_doctor with Doctor entry {
        here.receivables += self.we_pay;
    }

    can update_patient with Patient entry{
        here.balance += self.claim.cost - self.we_pay;
    }

    can update_person with Person entry {
        visit [here ->:Role:->];
        visit [here --> (`?Person) ->:Role:->];
    }

    can traverse with Claim entry {      
        visit [here -->];
    }

}


with entry{
    dr_house = Person("Gregory House");
    dr_house +>:Role:+> Doctor(specialty = "Internal Medicine");

    john_smith = Person("John Smith");
    john_smith +>:Role:+> Patient();

    dr_house +>:is_treating:+> john_smith;
    john_smith +>:treated_by:+> dr_house;

    claim = Claim(cost = 250);
    claim ++> john_smith;

    ClaimProcessing(claim, fraction = 0.7) spawn claim;

}