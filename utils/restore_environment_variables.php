<?php

/**
 * Prerequisites:
 * - "aws" cli installed and configured with access to backup bucket
 * - "platform" cli installed and configured with access to project variables
 * - "BACKUP_ENVVAR_ENCRYPTION_SECRET", "BACKUP_ENVVAR_S3_DIRECTORY" environment variables defined. Or, script executed with argument.
 */
final class EnvvarRestore
{
    const ENCRYPTION_SECRET_VARNAME = 'BACKUP_ENVVAR_ENCRYPTION_SECRET';
    const S3_DIRECTORY_VARNAME = 'BACKUP_ENVVAR_S3_DIRECTORY';
    const ENCRYPTION_METHOD_MAIN = 'AES-256-GCM';
    const ENCRYPTION_METHOD_FALLBACK = 'AES-256-CBC';

    private $dryRun;
    private $overrideExisting;
    private $secret;
    private $s3FilePath;
    private $tempDir = '/tmp';

    public function __construct($options)
    {
        $this->dryRun = isset($options['dry-run']);
        $this->overrideExisting = isset($options['override-existing']);
        $this->loadTmpDir($options);
        $this->loadSecret($options);
        $this->loadS3FilePath($options);
    }

    public function run()
    {
        $variablesFromBackup = $this->decrypt(
            $this->loadFromS3()
        );

        $this->restore($variablesFromBackup);
    }

    private function restore(array $variables)
    {
        $existVariables = $this->getExistingVars();

        $skipSame = [];
        $skipExist = [];
        $update = [];
        $create = [];
        foreach ($variables as $varToRestore) {
            if ($existVariables[$varToRestore['name']] === 'deploy') {
                continue;
            }
            $existing = $existVariables[$varToRestore['name']] ?? null;
            if ($existing) {
                if ($existing['value'] === $varToRestore['value']) {
                    $skipSame[] = $varToRestore;
                    continue;
                }
                if (!$this->overrideExisting) {
                    $skipExist[] = $varToRestore;
                    continue;
                }
                $update[] = $varToRestore;
                continue;
            }

            $create[] = $varToRestore;
        }
        $this->displayStats($create, $update, $skipSame, $skipExist);

        foreach ($create as $varToCreate) {
            $this->pushVariable($varToCreate, 'create');
        }
        foreach ($update as $varToCreate) {
            $this->pushVariable($varToCreate, 'update');
        }
    }

    private function loadFromS3(): array
    {
        $tmpFilePath = $this->tempDir . '/' . md5($this->s3FilePath) . time() . '.json.tmp';

        $cmd = "aws s3 cp {$this->s3FilePath} {$tmpFilePath} --quiet";
        echo PHP_EOL, $cmd;
        echo PHP_EOL, shell_exec($cmd);
        if (!file_exists($tmpFilePath)) {
            throw new \RuntimeException('Unable to download file from S3');
        }

        $data = json_decode(file_get_contents($tmpFilePath) ?: '{}', true);

        unlink($tmpFilePath);

        return $data;
    }

    private function decrypt(array $encrypted): array
    {
        // validate structure
        if (empty($encrypted['iv']) || empty($encrypted['tag']) || empty($encrypted['data'])) {
            throw new \InvalidArgumentException('Invalid file. "' . print_r($encrypted, true) . '"');
        }

        // detect Method to use
        $supportStrong = version_compare(PHP_VERSION, '7.1.0') >= 0;
        if (
            !empty($encrypted['method'])
            && \in_array($encrypted['method'], [self::ENCRYPTION_METHOD_MAIN, self::ENCRYPTION_METHOD_FALLBACK], true)
        ) {
            $method = $encrypted['method'];
            if (!$supportStrong && $method === self::ENCRYPTION_METHOD_MAIN) {
                throw new \RuntimeException('Unable to decrypt "' . $method . '" encrypted data.');
            }
        } else {
            $method = $supportStrong ? self::ENCRYPTION_METHOD_MAIN : self::ENCRYPTION_METHOD_FALLBACK;
        }
        $encrypted['iv'] = base64_decode($encrypted['iv']);
        $encrypted['tag'] = !empty($encrypted['tag']) ? base64_decode($encrypted['tag']) : '';
        $encrypted['data'] = base64_decode($encrypted['data']);
        if (!$supportStrong && $encrypted['tag']) {
            throw new \RuntimeException('Unable to decrypt "' . $method . '" encrypted data with tag.');
        }

        if ($encrypted['tag']) {
            $decryptedJson = openssl_decrypt(
                $encrypted['data'], $method, $this->secret, 0,
                $encrypted['iv'], $encrypted['tag']
            );
        } else {
            $decryptedJson = openssl_decrypt(
                $encrypted['data'], $method, $this->secret, 0,
                $encrypted['iv']
            );
        }

        if (empty($decryptedJson)) {
            throw new \RuntimeException('Unable to decrypt "data" key from file');
        }

        return json_decode($decryptedJson, true);
    }

    private function getExistingVars(): array
    {
        $varsFromCli = array_map(static function ($line) {
            return explode(',', $line, 3);
        }, array_filter(
            explode("\n", shell_exec('platform variables --format=csv --no-header'))
        ));

        $parsedVars = [];
        foreach ($varsFromCli as $var) {
            if (!$var[2]) {
                $unprefixedName = strpos($var[0], 'env:') === 0
                    ? substr($var[0], strlen('env:'))
                    : $var[0];
                $var[2] = getenv($unprefixedName);
            }

            $parsedVars[$var[0]] = [
                'name' => $var[0],
                'level' => $var[1],
                'value' => $var[2],
            ];
        }

        return $parsedVars;
    }

    private function loadSecret($options)
    {
        $this->secret = $options['secret'] ?? getenv(self::ENCRYPTION_SECRET_VARNAME);
        if (!$this->secret) {
            throw new \InvalidArgumentException(
                'Invalid encryption secret. Define "' . self::ENCRYPTION_SECRET_VARNAME . '" ' .
                'or use `--secret=val` argument'
            );
        }
    }

    private function loadS3FilePath($options)
    {
        $s3dir = $options['s3dir'] ?? getenv(self::S3_DIRECTORY_VARNAME);
        if (!$s3dir || strpos($s3dir, 's3://') !== 0) {
            throw new \InvalidArgumentException(
                'Invalid S3 Directory "' . $s3dir . '". Define "' . self::S3_DIRECTORY_VARNAME . '" ' .
                'or use `--s3dir=s3://bucket/folder` argument.'
            );
        }
        $s3file = $options['s3filename'] ?? 'null';
        if (!$s3file) {
            throw new \InvalidArgumentException(
                'Invalid S3 File "' . $s3file . '".  Use `--s3filename=fdacs_stageEnvVars_MON.json` argument.'
            );
        }

        $this->s3FilePath = rtrim($s3dir, '/') . '/' . $s3file;
    }

    private function loadTmpDir($options)
    {
        if (!empty($options['tmpdir']) && file_exists($options['tmpdir'])) {
            $this->tempDir = realpath($options['tmpdir']);
        }
        if (!$this->tempDir || !is_writable($this->tempDir)) {
            throw new \InvalidArgumentException(
                'Dir not writable: "' . $this->tempDir . '"' .
                'Make it writable or define other directory in `--tmpdir=/tmp` argument'
            );
        }
        $this->tempDir = rtrim($this->tempDir, '/');
    }

    private function displayStats($create, $update, $skipSame, $skipExist)
    {
        echo PHP_EOL, 'Restoring following variables:', PHP_EOL,
            'Update: (' . count($update) . ') ' . implode(', ', array_column($update, 'name')), PHP_EOL,
            'Create: (' . count($create) . ') ' . implode(', ', array_column($create, 'name')), PHP_EOL,
            'Skip (same): (' . count($skipSame) . ') ' . implode(', ', array_column($skipSame, 'name')), PHP_EOL,
            'Skip (exists): (' . count($skipExist) . ') ' . implode(', ', array_column($skipExist, 'name')), PHP_EOL;
        sleep(5);
    }

    /**
     * @param array $varToCreate
     * @param string $mode create | update
     */
    private function pushVariable($varToCreate, $mode = 'create')
    {
        $name = escapeshellarg($varToCreate['name']);
        $extraArgument = '';
        if ($mode === 'create' && strpos($varToCreate['name'], 'env:') === 0) {
            $name = escapeshellarg(substr($varToCreate['name'], 4));
            $extraArgument = '--prefix=env ';
        }
        if ($varToCreate['level'] === 'environment') {
            $extraArgument .= ' --environment=' . getenv('PLATFORM_BRANCH') . ' ';
            $extraArgument .= " --enabled={$varToCreate['is_enabled']} ";
            $extraArgument .= " --inheritable={$varToCreate['is_inheritable']} ";
        }

        $value = escapeshellarg($varToCreate['value']);
        $cmd = "platform variable:{$mode} " .
            ($mode === 'create' ? '--name=' : '') . $name .
            " --level={$varToCreate['level']} " .
            "--value={$value} " .
            "{$extraArgument} " .
            "--json={$varToCreate['is_json']} " .
            "--sensitive={$varToCreate['is_sensitive']} " .
            "--visible-build={$varToCreate['visible_build']} " .
            "--visible-runtime={$varToCreate['visible_runtime']}";
        echo PHP_EOL, $cmd;
        if (!$this->dryRun) {
            echo PHP_EOL, shell_exec($cmd);
        }
    }
}

/* ======================================================================================== */

$options = getopt('', ['tmpdir::', 'secret::', 's3dir::', 's3filename::', 'override-existing', 'dry-run', 'help']);
if (isset($options['help'])) {
    exit(
        'Usage:' . PHP_EOL .
        'php backup_environment_variables.php --dry-run --override-existing' .
        '--s3dir="s3://bucket/folder" ' .
        '--s3filename=project_stageEnvVars_MON.json ' .
        '--secret=encryption-secret-content ' .
        '--tmpdir=/tmp' . PHP_EOL
    );
}

try {
    (new EnvvarRestore($options))
        ->run();
} catch (\InvalidArgumentException $exc) {
    echo 'Error: ', PHP_EOL, $exc->getMessage(), PHP_EOL;
}
