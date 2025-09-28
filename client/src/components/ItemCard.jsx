import React, { useState } from 'react';
import { 
  HeartIcon, 
  ShareIcon, 
  EyeIcon, 
  PencilIcon, 
  TrashIcon,
  CalendarIcon,
  TagIcon,
  MapPinIcon,
  SparklesIcon
} from '@heroicons/react/24/outline';
import { HeartIcon as HeartSolidIcon } from '@heroicons/react/24/solid';
import { ITEM_CATEGORIES, RARITY_LEVELS } from '../api/userItemsApi';

const ItemCard = ({ 
  item, 
  onToggleFavorite, 
  onEdit, 
  onDelete, 
  onView, 
  onShare,
  className = '' 
}) => {
  const [isLoading, setIsLoading] = useState(false);

  const getCategoryInfo = (category) => {
    return ITEM_CATEGORIES.find(cat => cat.value === category) || 
           { label: category, icon: '📦' };
  };

  const getRarityInfo = (rarity) => {
    return RARITY_LEVELS.find(r => r.value === rarity) || 
           RARITY_LEVELS[0];
  };

  const handleToggleFavorite = async () => {
    if (isLoading) return;
    setIsLoading(true);
    try {
      await onToggleFavorite(item._id);
    } finally {
      setIsLoading(false);
    }
  };

  const formatDate = (date) => {
    return new Date(date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const categoryInfo = getCategoryInfo(item.category);
  const rarityInfo = getRarityInfo(item.rarity);
  const primaryImage = item.media?.images?.find(img => img.isPrimary) || 
                      item.media?.images?.[0];

  return (
    <div className={`
      group relative bg-white/10 backdrop-blur-md rounded-2xl border border-white/20 
      hover:border-white/40 transition-all duration-300 hover:scale-105 hover:shadow-2xl
      ${className}
    `}>
      {/* Rarity Glow Effect */}
      <div className={`
        absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-20 transition-opacity duration-300
        ${rarityInfo.value === 'legendary' ? 'bg-gradient-to-r from-yellow-400 to-orange-400' :
          rarityInfo.value === 'epic' ? 'bg-gradient-to-r from-purple-400 to-pink-400' :
          rarityInfo.value === 'rare' ? 'bg-gradient-to-r from-blue-400 to-cyan-400' :
          rarityInfo.value === 'uncommon' ? 'bg-gradient-to-r from-green-400 to-emerald-400' :
          'bg-gradient-to-r from-gray-400 to-gray-500'}
      `} />

      {/* Item Image */}
      <div className="relative h-48 rounded-t-2xl overflow-hidden bg-gradient-to-br from-gray-800 to-gray-900">
        {primaryImage ? (
          <img 
            src={primaryImage.url} 
            alt={item.name}
            className="w-full h-full object-cover"
            onError={(e) => {
              e.target.style.display = 'none';
              e.target.nextSibling.style.display = 'flex';
            }}
          />
        ) : null}
        
        {/* Fallback Icon */}
        <div className={`
          ${primaryImage ? 'hidden' : 'flex'} 
          w-full h-full items-center justify-center text-6xl
        `}>
          {categoryInfo.icon}
        </div>

        {/* Rarity Badge */}
        <div className={`
          absolute top-3 left-3 px-2 py-1 rounded-full text-xs font-semibold
          ${rarityInfo.bgColor} ${rarityInfo.color} border border-current/20
        `}>
          <SparklesIcon className="w-3 h-3 inline mr-1" />
          {rarityInfo.label}
        </div>

        {/* Favorite Button */}
        <button
          onClick={handleToggleFavorite}
          disabled={isLoading}
          className={`
            absolute top-3 right-3 p-2 rounded-full backdrop-blur-md transition-all duration-200
            ${item.metadata?.isFavorite 
              ? 'bg-red-500/20 text-red-400 hover:bg-red-500/30' 
              : 'bg-white/10 text-white/60 hover:bg-white/20 hover:text-white'
            }
            ${isLoading ? 'opacity-50 cursor-not-allowed' : 'hover:scale-110'}
          `}
        >
          {item.metadata?.isFavorite ? (
            <HeartSolidIcon className="w-5 h-5" />
          ) : (
            <HeartIcon className="w-5 h-5" />
          )}
        </button>

        {/* Action Buttons Overlay */}
        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center gap-2">
          <button
            onClick={() => onView(item)}
            className="p-2 bg-white/20 backdrop-blur-md rounded-full text-white hover:bg-white/30 transition-colors"
            title="View Details"
          >
            <EyeIcon className="w-5 h-5" />
          </button>
          
          <button
            onClick={() => onEdit(item)}
            className="p-2 bg-white/20 backdrop-blur-md rounded-full text-white hover:bg-white/30 transition-colors"
            title="Edit Item"
          >
            <PencilIcon className="w-5 h-5" />
          </button>
          
          <button
            onClick={() => onShare(item)}
            className="p-2 bg-white/20 backdrop-blur-md rounded-full text-white hover:bg-white/30 transition-colors"
            title="Share Item"
          >
            <ShareIcon className="w-5 h-5" />
          </button>
          
          <button
            onClick={() => onDelete(item)}
            className="p-2 bg-red-500/20 backdrop-blur-md rounded-full text-red-400 hover:bg-red-500/30 transition-colors"
            title="Delete Item"
          >
            <TrashIcon className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Item Content */}
      <div className="p-4 space-y-3">
        {/* Title and Category */}
        <div className="space-y-1">
          <h3 className="text-lg font-semibold text-white truncate">
            {item.name}
          </h3>
          <div className="flex items-center gap-2 text-sm text-gray-300">
            <span>{categoryInfo.icon}</span>
            <span>{categoryInfo.label}</span>
            {item.type && (
              <>
                <span>•</span>
                <span className="capitalize">{item.type}</span>
              </>
            )}
          </div>
        </div>

        {/* Description */}
        {item.description && (
          <p className="text-sm text-gray-400 line-clamp-2">
            {item.description}
          </p>
        )}

        {/* Tags */}
        {item.metadata?.tags && item.metadata.tags.length > 0 && (
          <div className="flex items-center gap-1 flex-wrap">
            <TagIcon className="w-4 h-4 text-gray-400" />
            {item.metadata.tags.slice(0, 3).map((tag, index) => (
              <span 
                key={index}
                className="px-2 py-1 bg-white/10 rounded-full text-xs text-gray-300"
              >
                {tag}
              </span>
            ))}
            {item.metadata.tags.length > 3 && (
              <span className="text-xs text-gray-400">
                +{item.metadata.tags.length - 3} more
              </span>
            )}
          </div>
        )}

        {/* Footer Info */}
        <div className="flex items-center justify-between pt-2 border-t border-white/10">
          {/* Acquisition Info */}
          <div className="flex items-center gap-2 text-xs text-gray-400">
            {item.location?.acquiredLocation && (
              <div className="flex items-center gap-1">
                <MapPinIcon className="w-3 h-3" />
                <span className="truncate max-w-20">
                  {item.location.acquiredLocation.venue || 'Location'}
                </span>
              </div>
            )}
            {item.location?.acquiredAt && (
              <div className="flex items-center gap-1">
                <CalendarIcon className="w-3 h-3" />
                <span>{formatDate(item.location.acquiredAt)}</span>
              </div>
            )}
          </div>

          {/* Value */}
          {(item.value?.points > 0 || item.value?.coins > 0) && (
            <div className="flex items-center gap-2 text-xs">
              {item.value.points > 0 && (
                <span className="text-yellow-400">
                  {item.value.points} pts
                </span>
              )}
              {item.value.coins > 0 && (
                <span className="text-blue-400">
                  {item.value.coins} coins
                </span>
              )}
            </div>
          )}
        </div>

        {/* Memories Count */}
        {item.metadata?.memories && item.metadata.memories.length > 0 && (
          <div className="text-xs text-purple-400 flex items-center gap-1">
            <span>💭</span>
            <span>{item.metadata.memories.length} memories</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default ItemCard;
