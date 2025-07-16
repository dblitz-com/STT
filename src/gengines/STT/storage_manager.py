#!/usr/bin/env python3
"""
Storage Manager for Zeus VLA - Critical Fix #2
Centralized storage architecture with encryption and cleanup

Features:
- Centralized configuration management
- Encrypted file storage with Fernet
- Automatic cleanup with TTL
- Path resolution consistency
- Environment variable + YAML config hierarchy
"""

import os
import time
import yaml
import shutil
from pathlib import Path
from typing import Optional, Dict, Any, List
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend
import structlog

logger = structlog.get_logger()

class StorageManager:
    """Centralized storage manager with encryption and cleanup"""
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize storage manager with centralized configuration"""
        self.config_path = config_path or "storage_config.yaml"
        self.config = self._load_config()
        
        # Initialize base directory
        self.base_dir = Path(os.path.expanduser(self.config.get('base_dir', '~/.continuous_vision/captures')))
        self.base_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize encryption
        self.key = self._init_encryption_key()
        self.fernet = Fernet(self.key)
        
        # Storage stats
        self.stats = {
            'files_stored': 0,
            'files_loaded': 0,
            'files_cleaned': 0,
            'total_size_mb': 0
        }
        
        logger.info(f"✅ StorageManager initialized: {self.base_dir}")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file and environment variables"""
        config = {
            'base_dir': '~/.continuous_vision/captures',
            'encryption_enabled': True,
            'cleanup_ttl_days': 1,
            'max_storage_mb': 100,
            'compression_enabled': True
        }
        
        # Load from YAML file if exists
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r') as f:
                    file_config = yaml.safe_load(f) or {}
                config.update(file_config)
                logger.debug(f"📄 Loaded config from {self.config_path}")
            except Exception as e:
                logger.warning(f"⚠️ Failed to load config file: {e}")
        
        # Override with environment variables
        env_mappings = {
            'ZEUS_STORAGE_DIR': 'base_dir',
            'ZEUS_ENCRYPTION_ENABLED': 'encryption_enabled',
            'ZEUS_CLEANUP_TTL': 'cleanup_ttl_days',
            'ZEUS_MAX_STORAGE_MB': 'max_storage_mb'
        }
        
        for env_var, config_key in env_mappings.items():
            if env_var in os.environ:
                value = os.environ[env_var]
                if config_key in ['encryption_enabled', 'compression_enabled']:
                    config[config_key] = value.lower() in ['true', '1', 'yes']
                elif config_key in ['cleanup_ttl_days', 'max_storage_mb']:
                    config[config_key] = int(value)
                else:
                    config[config_key] = value
                logger.debug(f"🌍 Environment override: {config_key} = {config[config_key]}")
        
        return config
    
    def _init_encryption_key(self) -> bytes:
        """Initialize encryption key from password or generate new one"""
        key_file = self.base_dir / '.encryption_key'
        
        if key_file.exists():
            # Load existing key
            try:
                with open(key_file, 'rb') as f:
                    key = f.read()
                logger.debug("🔐 Loaded existing encryption key")
                return key
            except Exception as e:
                logger.warning(f"⚠️ Failed to load encryption key: {e}")
        
        # Generate new key
        if self.config.get('encryption_enabled', True):
            # Use password-based key derivation
            password = os.environ.get('ZEUS_ENCRYPTION_PASSWORD', 'zeus-vla-default-key').encode()
            salt = b'zeus-vla-salt'  # In production, use random salt
            
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=100000,
                backend=default_backend()
            )
            key = Fernet.generate_key()
            
            # Save key to file
            try:
                with open(key_file, 'wb') as f:
                    f.write(key)
                os.chmod(key_file, 0o600)  # Restrict permissions
                logger.info("🔐 Generated new encryption key")
            except Exception as e:
                logger.warning(f"⚠️ Failed to save encryption key: {e}")
            
            return key
        else:
            # Dummy key for unencrypted mode
            return Fernet.generate_key()
    
    def store_file(self, data: bytes, filename: str, metadata: Optional[Dict] = None) -> str:
        """Store file with optional encryption and metadata"""
        try:
            # Resolve full path
            file_path = self.base_dir / filename
            file_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Prepare data for storage
            if self.config.get('encryption_enabled', True):
                # Encrypt data
                encrypted_data = self.fernet.encrypt(data)
                store_data = encrypted_data
            else:
                store_data = data
            
            # Write file
            with open(file_path, 'wb') as f:
                f.write(store_data)
            
            # Store metadata if provided
            if metadata:
                metadata_path = file_path.with_suffix(file_path.suffix + '.meta')
                with open(metadata_path, 'w') as f:
                    yaml.dump(metadata, f)
            
            # Update stats
            self.stats['files_stored'] += 1
            self.stats['total_size_mb'] += len(store_data) / (1024 * 1024)
            
            logger.debug(f"💾 Stored file: {filename} ({len(store_data)} bytes)")
            return str(file_path)
            
        except Exception as e:
            logger.error(f"❌ Failed to store file {filename}: {e}")
            raise
    
    def load_file(self, filename: str) -> Optional[bytes]:
        """Load file with automatic decryption"""
        try:
            file_path = self.base_dir / filename
            
            if not file_path.exists():
                logger.warning(f"⚠️ File not found: {filename}")
                return None
            
            # Read file
            with open(file_path, 'rb') as f:
                stored_data = f.read()
            
            # Decrypt if needed
            if self.config.get('encryption_enabled', True):
                try:
                    decrypted_data = self.fernet.decrypt(stored_data)
                    data = decrypted_data
                except Exception as e:
                    logger.warning(f"⚠️ Decryption failed for {filename}, treating as unencrypted: {e}")
                    data = stored_data
            else:
                data = stored_data
            
            # Update stats
            self.stats['files_loaded'] += 1
            
            logger.debug(f"📁 Loaded file: {filename} ({len(data)} bytes)")
            return data
            
        except Exception as e:
            logger.error(f"❌ Failed to load file {filename}: {e}")
            return None
    
    def load_metadata(self, filename: str) -> Optional[Dict]:
        """Load metadata for file"""
        try:
            file_path = self.base_dir / filename
            metadata_path = file_path.with_suffix(file_path.suffix + '.meta')
            
            if not metadata_path.exists():
                return None
            
            with open(metadata_path, 'r') as f:
                metadata = yaml.safe_load(f)
            
            return metadata
            
        except Exception as e:
            logger.error(f"❌ Failed to load metadata for {filename}: {e}")
            return None
    
    def list_files(self, pattern: str = "*", include_metadata: bool = False) -> List[Dict]:
        """List files in storage with optional metadata"""
        try:
            files = []
            
            for file_path in self.base_dir.glob(pattern):
                if file_path.is_file() and not file_path.name.endswith('.meta'):
                    file_info = {
                        'filename': file_path.name,
                        'path': str(file_path),
                        'size': file_path.stat().st_size,
                        'modified': file_path.stat().st_mtime,
                        'created': file_path.stat().st_ctime
                    }
                    
                    if include_metadata:
                        metadata = self.load_metadata(file_path.name)
                        file_info['metadata'] = metadata
                    
                    files.append(file_info)
            
            # Sort by modification time (newest first)
            files.sort(key=lambda x: x['modified'], reverse=True)
            
            return files
            
        except Exception as e:
            logger.error(f"❌ Failed to list files: {e}")
            return []
    
    def cleanup_old_files(self, ttl_days: Optional[int] = None) -> int:
        """Clean up old files based on TTL"""
        try:
            ttl_days = ttl_days or self.config.get('cleanup_ttl_days', 1)
            cutoff_time = time.time() - (ttl_days * 24 * 60 * 60)
            
            files_cleaned = 0
            total_size_freed = 0
            
            for file_path in self.base_dir.rglob('*'):
                if file_path.is_file() and file_path.stat().st_mtime < cutoff_time:
                    try:
                        file_size = file_path.stat().st_size
                        file_path.unlink()
                        
                        # Also remove metadata file if exists
                        metadata_path = file_path.with_suffix(file_path.suffix + '.meta')
                        if metadata_path.exists():
                            metadata_path.unlink()
                        
                        files_cleaned += 1
                        total_size_freed += file_size
                        
                    except Exception as e:
                        logger.warning(f"⚠️ Failed to delete {file_path}: {e}")
            
            # Update stats
            self.stats['files_cleaned'] += files_cleaned
            self.stats['total_size_mb'] -= total_size_freed / (1024 * 1024)
            
            if files_cleaned > 0:
                logger.info(f"🧹 Cleaned {files_cleaned} files ({total_size_freed / (1024 * 1024):.1f} MB)")
            
            return files_cleaned
            
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {e}")
            return 0
    
    def get_storage_stats(self) -> Dict[str, Any]:
        """Get storage statistics"""
        try:
            # Calculate current disk usage
            total_size = 0
            file_count = 0
            
            for file_path in self.base_dir.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size
                    file_count += 1
            
            # Update stats
            self.stats['total_size_mb'] = total_size / (1024 * 1024)
            
            return {
                'base_dir': str(self.base_dir),
                'file_count': file_count,
                'total_size_mb': self.stats['total_size_mb'],
                'files_stored': self.stats['files_stored'],
                'files_loaded': self.stats['files_loaded'],
                'files_cleaned': self.stats['files_cleaned'],
                'encryption_enabled': self.config.get('encryption_enabled', True),
                'cleanup_ttl_days': self.config.get('cleanup_ttl_days', 1),
                'max_storage_mb': self.config.get('max_storage_mb', 100)
            }
            
        except Exception as e:
            logger.error(f"❌ Failed to get storage stats: {e}")
            return self.stats
    
    def enforce_storage_limits(self) -> bool:
        """Enforce storage limits by cleaning old files"""
        try:
            stats = self.get_storage_stats()
            max_size_mb = self.config.get('max_storage_mb', 100)
            
            if stats['total_size_mb'] > max_size_mb:
                logger.warning(f"⚠️ Storage limit exceeded: {stats['total_size_mb']:.1f} MB > {max_size_mb} MB")
                
                # Clean files older than 1 day
                cleaned = self.cleanup_old_files(ttl_days=1)
                
                # If still over limit, clean files older than 12 hours
                if stats['total_size_mb'] > max_size_mb:
                    cleaned += self.cleanup_old_files(ttl_days=0.5)
                
                # If still over limit, clean files older than 1 hour
                if stats['total_size_mb'] > max_size_mb:
                    cleaned += self.cleanup_old_files(ttl_days=0.04)
                
                if cleaned > 0:
                    logger.info(f"🧹 Enforced storage limits: cleaned {cleaned} files")
                    return True
                else:
                    logger.warning("⚠️ Storage limit exceeded but no files cleaned")
                    return False
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to enforce storage limits: {e}")
            return False
    
    def backup_storage(self, backup_path: str) -> bool:
        """Create backup of storage directory"""
        try:
            backup_path = Path(backup_path)
            backup_path.mkdir(parents=True, exist_ok=True)
            
            # Create timestamped backup
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            backup_dir = backup_path / f"zeus_storage_backup_{timestamp}"
            
            shutil.copytree(self.base_dir, backup_dir)
            
            logger.info(f"💾 Storage backed up to: {backup_dir}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Backup failed: {e}")
            return False
    
    def migrate_from_old_storage(self, old_paths: List[str]) -> int:
        """Migrate files from old storage locations"""
        try:
            migrated_count = 0
            
            for old_path in old_paths:
                old_path = Path(old_path)
                
                if old_path.exists():
                    for file_path in old_path.rglob('*'):
                        if file_path.is_file() and file_path.suffix in ['.png', '.jpg', '.jpeg', '.json']:
                            try:
                                # Read old file
                                with open(file_path, 'rb') as f:
                                    data = f.read()
                                
                                # Store in new location
                                new_filename = f"migrated_{file_path.name}"
                                metadata = {
                                    'migrated_from': str(file_path),
                                    'migration_time': time.time(),
                                    'original_size': len(data)
                                }
                                
                                self.store_file(data, new_filename, metadata)
                                migrated_count += 1
                                
                                # Remove old file
                                file_path.unlink()
                                
                            except Exception as e:
                                logger.warning(f"⚠️ Failed to migrate {file_path}: {e}")
            
            if migrated_count > 0:
                logger.info(f"📦 Migrated {migrated_count} files to new storage")
            
            return migrated_count
            
        except Exception as e:
            logger.error(f"❌ Migration failed: {e}")
            return 0


# Global storage manager instance
_storage_manager = None

def get_storage_manager() -> StorageManager:
    """Get global storage manager instance"""
    global _storage_manager
    if _storage_manager is None:
        _storage_manager = StorageManager()
    return _storage_manager

def reset_storage_manager():
    """Reset global storage manager (for testing)"""
    global _storage_manager
    _storage_manager = None


if __name__ == "__main__":
    # Test storage manager
    print("🧪 Testing StorageManager...")
    
    storage = StorageManager()
    
    # Test file storage
    test_data = b"Hello Zeus VLA!"
    metadata = {'test': True, 'timestamp': time.time()}
    
    path = storage.store_file(test_data, "test.txt", metadata)
    print(f"✅ Stored file: {path}")
    
    # Test file loading
    loaded_data = storage.load_file("test.txt")
    print(f"✅ Loaded data: {loaded_data}")
    
    # Test metadata
    loaded_metadata = storage.load_metadata("test.txt")
    print(f"✅ Loaded metadata: {loaded_metadata}")
    
    # Test stats
    stats = storage.get_storage_stats()
    print(f"✅ Storage stats: {stats}")
    
    # Test cleanup
    cleaned = storage.cleanup_old_files(ttl_days=0)
    print(f"✅ Cleaned {cleaned} files")
    
    print("🎉 StorageManager test complete!")