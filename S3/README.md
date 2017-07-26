# AWS-S3
Requires you to be authorized logged in user. Scans through all the buckets 
under your account and lists those buckets which are public (read/write) or
public (read_acp, write_acp) or full_control access.
It also attempts to set these back to private and notifies you if it fails
while setting it to private.
