{
  trustProxyEnv = mechanism:
    if mechanism == "express" then { TRUST_PROXY = "1"; }
    else if mechanism == "uvicorn" then { FORWARDED_ALLOW_IPS = "*"; }
    else { };
}
