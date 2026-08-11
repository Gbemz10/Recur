from pydantic import BaseModel, Field, model_validator


class OtpRequest(BaseModel):
    email: str | None = None
    phone: str | None = None

    @model_validator(mode="after")
    def require_exactly_one_contact(self) -> "OtpRequest":
        if bool(self.email) == bool(self.phone):
            raise ValueError("Provide exactly one of email or phone.")
        return self


class OtpRequestResponse(BaseModel):
    message: str
    dev_otp: str | None = None


class OtpVerifyRequest(OtpRequest):
    code: str = Field(min_length=6, max_length=6)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class UserProfile(BaseModel):
    id: str
    email: str | None
    phone: str | None
