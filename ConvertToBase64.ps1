$test = "-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA9r9kh+UHFOrwL+H6YbeZ11ULaN/lZI0pOFXpWKAlh07MbreK
C0O3QTW5Ar81nArYSjSos0mKQ9Petlwy7ZugH0zgBxTn7s409x0E8VJxQSGWt6lx
59pX0Tca6rncWYrpctkE/zriTsOnHmwLQfgWpVqe4EcfDDi1Lj7GdgFdb/Ca0+Zw
zUEIaSkc9ifc6xlUluujnmGq1/Aao27QkGA/xpliZCBQ7kzfG8Jnij/EOYezr7tj
pZvISlp0VtZLFM0/EEdXI4J9eNcIT2nDQQEQ/azX8UAUinLJeuaBXU3otwCWY1qQ
gzN1S8qxjJo1ThGTPNpmqpVucTh8e6tsdd98BwIDAQABAoIBAQDctXP57k24UzHG
0s6Aq5bLOsH67BKnL3EIeChCYvVOo5hPDJNI4ihABwrXPyt3yWeQcKvZutUXOKOE
4NGZIdRHSx80lmmjfQV5aJasOT8esCm9XK6LYg2dETpdbSSBX7TTSvWiSwx0waNx
ndkwB/ZRr85e9J778pl1pScmFLB8V6y1YkOTLy8LDpTSyjYm/XYp9c3Xwuc6m7Rg
xGGyQSe0OWQz3EMidsSmlw4dsjORgUOUsPw9DZYcRbvm7a+Q/U7vecp49ArhXaPK
EFk6PRTH9r6voIkE9L55JASFyB3IBvKXfOOsA/u3ltTJQ4BmOhWg0spXMJwpZ3oV
BrY61pLJAoGBAPxOFtWGXp4UBHQIKHQr335/dXif9zixovfQOBDeR5SnsEd2R8fh
XmwjTxXWQQQmK9W9fIW/UFfA3dbaNHBD91NzDRZXMMyboweqt6AKc73ekgUI4/SE
88s5ZBsaafe+o3beWgPf7IFTRI0pNuVWcsfr9Qs/wo9QsE2a11gqFKKbAoGBAPpc
d+YxAbMm4EgHJJch+9dX2E4Ja/3rMZs2o6OJ48QvlV/IdSZ/Fy4Q2+7KdBHOVHFR
AxvMO6SwVivhQCPhznUaPVCL+RNh8zQpnV3dO1IGcjosXwEnMpBWjmxifwec1PXq
0UaHoqT7UiRnwPOqsnxdYSPXrBu1/bBu0bK4kl0FAoGBALq8LQhCGBtVY2phc1dv
9U0Rlub9NiN+zcguEqDhcwciCUUK1NuqAJF2nJzj42Dnw3/Ba70tuJAKTeYrv63r
j8zylRgY1iRJeKM/BgLsWXeImHgjeVvLXwjlZCLvLMjRDvj2XpcJj2i0MUNs4pVg
ozk2eTmnKh+aL7JwTLuTAYzLAoGAew/0x6uTIFKdsAoCzF8iAYnmgwVSle+D5L2I
1hwzXv3cuMY5/4A9DqGu2cOeJhp7m2+szX8oWh1rXgpMktatuxX4yZzkA8kD2MIT
3k2emQUeJMYmtNRloFlLjK8lrcJDU9XmpHqLUflPOSHe0Gc5cLQdyZZ7vOtKFe2D
GgxrtVkCgYEA4TPCl3pXlTxKj6sSchhSM2023LQKUO62NkF97yru6IqPchnzVHwD
hSGHlpZMAIoVrHgd1gxNRZI1M1NzJmK05YtCcKgx7y8dcpnGK54iq1FS0iGuCmYz
gg2Ub1LVGIrk5JfnJep9ZtGd9dCXSFX+5aF2SxtvNmx+fHYUU/2A35o=
-----END RSA PRIVATE KEY-----"

#convert the cert to Base64
[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\RobertLarkin\Downloads\chef_cert.cer")) > "C:\Users\RobertLarkin\Downloads\chef-cert383.txt"

[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\RobertLarkin\Downloads\chef_cert.cer")) > "C:\Users\RobertLarkin\Downloads\chef-cert333.txt"
#Convert back
$fileContentBytes = get-content 'C:\Users\RobertLarkin\Downloads\fuckcert.txt'
$fileContentBytes

$Cert = [System.Text.Encoding]::utf8.GetString([System.Convert]::FromBase64String($fileContentBytes))
$Cert | Out-File 'C:\Users\RobertLarkin\Downloads\testetset.txt'
$fileContentBytes.TrimEnd("`n")



$inputfile  = "C:\Users\RobertLarkin\Downloads\chef_cert.cer"
$base64String = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($InputFile))


$outFile = "${InputFile}.base64"
[System.IO.File]::WriteAllText($outFile, $base64String)

#convert back
$outfile  = "C:\Users\RobertLarkin\Downloads\certest-colin.cer"

$out64version = get-content $outFile 
$Cert = [System.Text.Encoding]::utf8.GetString([System.Convert]::FromBase64String($out64version))
$Cert | Out-File 'C:\Users\RobertLarkin\Downloads\testMON.txt'