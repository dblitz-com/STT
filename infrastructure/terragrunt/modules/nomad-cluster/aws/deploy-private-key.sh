#!/bin/bash
# Deploy new GitHub App private key via webhook self-update mechanism
# This script embeds the private key and updates it on the bastion host

set -e

echo "Deploying new GitHub App private key..."

# Create or update the private key file
sudo tee /opt/webhook/github-app/private-key.pem << 'PRIVATE_KEY_EOL'
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0F3EVKyZoTho/8fcJCv6yq05WwiioBF0D9q46Hdv7p/M0EiH
rAPrZr91/wb+oaqSL7r9sG9hzWFqjhSetUOatbzFTPILB8UiJEraoJjDVPSY129V
uZjDNla3Al30rz+OuPTfOgoDADSLLbVJNy+taMQ8HwkvMnx8ufNLNgbQ53h+WYU0
zQ1C7wvk8Q0k4YdgCnbwWco7eL3gpD54wi+dXVM83eN8X+sJLfj5Aoer879dRG3T
k0K2cRc/iplvkginjOplSU+4m3EL7IZQ/9tasYghOnOch49T54M/PIoORR4S8RUo
LPcwxMacE7K3ZvBMyPTQ/h9XB2lFgADKgXv3LwIDAQABAoIBAC0KyAEh2of+YLxC
IPV0yF79uTNTl4wQmc0/k8802m5z/ttbgnCN3Fo2szQw9+RMshM9Uc/NFBBIqbcT
AAfhGFWG/AOZIwdH9wxvXflvbHI1+cBAYgCf5Dsf3anWU6l6jMiwrnymY2Ws9hUo
Zi5W0R6fpPt0ic5ZGME9tZl1Ob1/a61pZ4A8qm6cF67CTDbyqGPieY80JQxi0uvs
ucKc/ENe0jO7h9i3jMWf4941S7bv4frRdUSeVTNWZq4XH9+imAxr7/kMiqsTwrfO
6j/APA7Dc2yRnZECSsQ4r6o4b/PrBaQTB3/LjIQsW3pSp5bw+cjpDwjpfUJENg6a
AGX0FDECgYEA74VhQSg01XAHmhAYKoOVl017WLSE9eBnxQB6xWPT6MK2DB5bcB+b
HnlTRTI9LZLZFd0HXRViz2ODSRSpbNADZky/vMYwTS8p4VCzl00Sbr1AE30es2/l
glGPfIsMfY0mDknVJuiTH1zPbrviiJsfsOyPWW/Xq8YcvDLCpJAwxScCgYEA3rOq
uHh666zVTgaPsfk0ozuaVKpRSLGL6lStf4ToDwVH2k7+y2SXA5pqXoCrv6lsIEmT
mb7Fk90s2qRPIfzLWIG1Fi4lxHGHVlilGOFFSLVaGjUnesyHuW9Ku/kQht0s/WMq
6B3dS4r4P+OHgZU29pNATDS7mqKLScU6Q1yRUrkCgYABSzUlRvRSGtLPsDqRMDjE
onSCHCeDtHybAc+n9UwVu8eD9T4FMwaBeaJLg2P1NQ/bIGCDzjPEbwMsh+IKZm0+
Rjfa6y8jm5ecUfVGYfIxivAnqstZqMcSlyIxSAb/Pp3wAdIW7baturCcJoOovT3E
lOKJVyNRGDbbhWKrxOOejQKBgDQUVBI7qpM+octTYXs/Sf36TEcMZWHYk13DW6d8
j0Aj/f+hhZhO97nR/JoJASEbH7wVOL01jcLccEbZMeBC29Lg0lZTiGV+HyYkKMe+
tpMgRefnEkp3Vi4ZRqLaxfCj/IdtD3WktkGaSB+4t9Gn8WiMWvb3RgANjwE7bDqg
hSORAoGBAOopKs7T5i41PBihk47wY3H7q0gIzKaqomMyj2w0tJFAIUemvvBkKFhD
Twb54FqAhfEuvmw/xcQoVz1gnlrpUjFMsDvcwyeJojFT8QNY0RzJMw8ETSWx/2B9
8mDltJMXuXQqk9UfAX4H8bbZehExaiJuHB4U5w6SbbApK6a9ToiZ
-----END RSA PRIVATE KEY-----
PRIVATE_KEY_EOL

# Set proper permissions
sudo chmod 600 /opt/webhook/github-app/private-key.pem
sudo chown webhook:webhook /opt/webhook/github-app/private-key.pem

echo "GitHub App private key deployed successfully!"

# Test the authentication
echo "Testing GitHub App authentication..."
if /opt/webhook/github-app/get-token.sh > /dev/null 2>&1; then
    echo "✅ GitHub App authentication test successful!"
    echo "Private key deployment completed successfully!"
    
    # Remove self-update trigger if it exists
    rm -f /tmp/webhook-self-update-needed
else
    echo "❌ GitHub App authentication test failed"
    exit 1
fi