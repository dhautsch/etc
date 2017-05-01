
def get_boto3_SAMLAssertion(idp_url, user_name, user_password, assume_role=None, proxy_url=None):
    import requests
    import codecs
    import os
    from xml.etree import ElementTree
    from bs4 import BeautifulSoup
    from requests_ntlm import HttpNtlmAuth

    session_ = requests.Session()

    # Programatically get the SAML assertion
    # Set up the NTLM authentication handler by using the provided credential
    session_.auth = HttpNtlmAuth(user_name, user_password, session_)

    form_based_ = True

    # Opens the initial AD FS URL and follows all of the HTTP 302 redirects
    # To support Form based Auth; specify the user-agent type
    if form_based_:
        headers_ = {'User-Agent': 'Mozilla/5.0 (compatible, MSIE 11, Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko'}
        response_ = session_.get(idp_url, headers = headers_)
    else:
        response_ = session_.get(idp_url)

    soup_ = BeautifulSoup(response_.text, "html.parser")

    saml_response = ''
    # Look for the SAMLResponse attribute of the input tag. Looks like <input type="hidden" name="SAMLResponse" value="...base64encoded..." />
    for elem in soup_.find_all('input', attrs={'name': 'SAMLResponse'}):
        saml_response_ = codecs.decode(elem.get('value').encode('ascii'), 'base64').decode('utf-8')
        break

    # Overwrite and delete the credential variables, just for safety
    user_name = '##############################################'
    user_password = '##############################################'
    del user_name
    del user_password

    if not saml_response_:
        return None

    # Proxy Setup if provided
    if proxy_url is not None:
        os.environ['HTTP_PROXY'] = proxy_url
        os.environ['HTTPS_PROXY'] = proxy_url

    # Read the role from SAML response and choose to assume
    attrib_name_ = 'https://aws.amazon.com/SAML/Attributes/Role'
    tree_ = ElementTree.fromstring(saml_response_)
    assertion_ = tree_.find('{urn:oasis:names:tc:SAML:2.0:assertion}Assertion')

    attrib_values_ = list()
    for attribute_ in assertion_.findall('.//{urn:oasis:names:tc:SAML:2.0:assertion}Attribute[@Name]'):
        if attribute_.attrib['Name'] == attrib_name_:
            for val_ in attribute_.findall('{urn:oasis:names:tc:SAML:2.0:assertion}AttributeValue'):
                attrib_values_.append(val_.text)

    aws_roles_ = list()
    principal_arn_ = None
    role_arn_ = None

    for att_val_ in attrib_values_:
        # arn:aws:iam::123456789012:saml-provider/ProviderNameInAWS,arn:aws:iam::123456789012:role/RoleNameInAWS
        principal_arn_, role_arn_ = att_val_.split(',')
        if 'saml-provider' in role_arn_:
            p_arn_ = principal_arn_
            principal_arn_ = role_arn_
            role_arn_ = p_arn_
        aws_roles_.append((principal_arn_, role_arn_))
        if role_arn_.split('/')[1] == assume_role:
            break
        else:
            role_arn_ = None

    if role_arn_ is None:
        if len(aws_roles_) is 0:
            print('You do not have federated access to AWS', file=sys.stderr)
        elif len(aws_roles_) > 0:
            aws_roles_.sort()
            for (p_arn_, r_arn_) in aws_roles_:
                print('Choose one of the following roles:', file=sys.stderr)
                print('\t' + r_arn_.split(':')[4] + ' => ' + r_arn_.split('/')[1], file=sys.stderr)
        return None
    else:
        return { 'PrincipalArn' : principal_arn_, 'RoleArn' : role_arn_, 'SAMLAssertion' : codecs.encode(saml_response_.encode('utf-8'), 'base64').decode('ascii').replace('\n', '') }
