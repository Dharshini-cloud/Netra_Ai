function weights = extractWeights(net)
% EXTRACTWEIGHTS Extracts weights and biases from neural network layers.
    weights = struct();
    if isempty(net) || ~isprop(net, 'Layers')
        weights.placeholder.W = 0;
        weights.placeholder.b = 0;
        return;
    end
    for i = 1:numel(net.Layers)
        lName = matlab.lang.makeValidName(net.Layers(i).Name);
        if isprop(net.Layers(i), 'Weights') && ~isempty(net.Layers(i).Weights)
            weights.(lName).W = net.Layers(i).Weights;
        end
        if isprop(net.Layers(i), 'Bias') && ~isempty(net.Layers(i).Bias)
            weights.(lName).b = net.Layers(i).Bias;
        end
    end
end
