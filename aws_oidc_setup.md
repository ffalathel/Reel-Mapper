# Setting up AWS OIDC and SSM for GitHub Actions

This is a **Zero Trust** setup. Instead of valid long-term keys (like your `.pem` file), GitHub will "assume" a role for a few minutes to deploy.

## Part 1: Attach SSM Role to Your EC2 Instance
Your EC2 instance needs permission to listen to the AWS Systems Manager.

1.  Go to the **AWS Console** -> **EC2** -> **Instances**.
2.  Select your instance (`Reel Mapper`).
3.  Click **Actions** -> **Security** -> **Modify IAM role**.
4.  If one is already attached, note its name. If not, click **Create new IAM role**:
    *   **Trust entity**: AWS Service -> EC2.
    *   **Policies**: Search for and check `AmazonSSMManagedInstanceCore`.
    *   **Name**: `EC2SSMRole`.
    *   **Create**.
5.  Back in the "Modify IAM role" tab, hit refresh, select `EC2SSMRole`, and click **Update IAM role**.

## Part 2: Create OIDC Provider (Connect GitHub to AWS)
1.  Go to **IAM** -> **Identity providers**.
2.  Click **Add provider**.
3.  **Type**: OpenID Connect.
4.  **Provider URL**: `https://token.actions.githubusercontent.com`
5.  **Audience**: `sts.amazonaws.com`
6.  Click **Add provider**.

## Part 3: Create the Deployer Role
1.  Go to **IAM** -> **Roles** -> **Create role**.
2.  Select **Web identity**.
3.  **Identity provider**: Select the one you just created (`token.actions.githubusercontent.com`).
4.  **Audience**: `sts.amazonaws.com`.
5.  **GitHub Organization**: `ffalathel` (from your repo URL).
6.  **GitHub Repository**: `Reel-Mapper`.
7.  Click **Next**.
8.  **Permissions**:
    *   Search for `AmazonSSMFullAccess` (or simpler: create a policy allowing `ssm:SendCommand` on your instance). For now, `AmazonSSMFullAccess` is easiest to verify.
9.  Click **Next**.
10. **Role Name**: `GitHubDeployRole`.
11. **Create role**.
12. **Copy the ARN** of this role (e.g., `arn:aws:iam::123456789012:role/GitHubDeployRole`). You will need this for GitHub Secrets.

## Part 4: Add Secrets to GitHub
Go to your Repo Settings -> Secrets -> Actions.

1.  **AWS_ROLE_ARN**: Paste the ARN you copied in Step 3.
2.  **EC2_INSTANCE_ID**: Go to EC2 Console, copy your Instance ID (e.g., `i-0123456789abcdef0`).
3.  **AWS_REGION**: `us-east-2` (Your current region).
